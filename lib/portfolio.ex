defmodule Portfolio do
  @moduledoc """
  The aggregate root: what one investor owns (holdings and cash) and what they
  aim for (an allocation).

  A portfolio can only be built through `new/1`, which enforces R1–R4 of
  `design/domain-model.md`, so every `%Portfolio{}` that exists is valid.

  Holdings map a ticker to a quantity of shares; the allocation maps a ticker to
  a weight. Prices are not stored here: they come from the market each rebalance
  is computed against (ADR 0002).

  ## Example

  The worked example of the domain model, day 2: prices moved and NVDA drifted
  above its half.

      iex> {:ok, portfolio} =
      ...>   Portfolio.new(
      ...>     holdings: %{
      ...>       "AAPL" => Decimal.new("7.142857"),
      ...>       "MSFT" => Decimal.new("4.761904"),
      ...>       "NVDA" => Decimal.new("23.809523")
      ...>     },
      ...>     cash: Decimal.new("0.000620"),
      ...>     allocation: %{
      ...>       "AAPL" => Decimal.new("0.25"),
      ...>       "MSFT" => Decimal.new("0.25"),
      ...>       "NVDA" => Decimal.new("0.50")
      ...>     }
      ...>   )
      iex> market = [
      ...>   %Portfolio.Stock{ticker: "AAPL", price: Decimal.new(310)},
      ...>   %Portfolio.Stock{ticker: "MSFT", price: Decimal.new(505)},
      ...>   %Portfolio.Stock{ticker: "NVDA", price: Decimal.new(250)}
      ...> ]
      iex> {:ok, trades} = Portfolio.rebalance(portfolio, market, 6)
      iex> Enum.map(
      ...>   trades,
      ...>   &{&1.side, &1.ticker, Decimal.to_string(&1.quantity)}
      ...> )
      [
        {:sell, "NVDA", "2.666666"},
        {:buy, "AAPL", "1.382488"},
        {:buy, "MSFT", "0.471476"}
      ]
  """

  alias Portfolio.{Rebalance, Stock, Trade}

  @type ticker :: String.t()
  @type t :: %__MODULE__{
          holdings: %{ticker() => Decimal.t()},
          cash: Decimal.t(),
          allocation: %{ticker() => Decimal.t()}
        }

  @enforce_keys [:holdings, :cash, :allocation]
  defstruct [:holdings, :cash, :allocation]

  @typedoc "One error per line of the *Errors* table in `design/domain-model.md`."
  @type error ::
          {:weight_out_of_range, ticker()}
          | {:weights_do_not_sum_to_one, Decimal.t()}
          | {:negative_quantity, ticker()}
          | :negative_cash
          | {:missing_price, ticker()}
          | {:non_positive_price, ticker()}
          | {:duplicate_stock, ticker()}
          | {:invalid_precision, term()}
          | {:quantity_exceeds_precision, ticker()}
          | {:not_enough_shares, ticker()}
          | {:not_enough_cash, ticker()}

  @doc """
  Builds a portfolio from `holdings:`, `cash:` and `allocation:`.

  Returns `{:error, error}` for the lowest-numbered rule broken (E1–E4), and
  within it for the first ticker in alphabetical order.
  """
  @spec new(keyword()) :: {:ok, t()} | {:error, error()}
  def new(fields) do
    holdings = Keyword.fetch!(fields, :holdings)
    cash = Keyword.fetch!(fields, :cash)
    allocation = Keyword.fetch!(fields, :allocation)

    with :ok <- first_breaking(allocation, &in_unit_range?/1, :weight_out_of_range),
         :ok <- check_weights_sum(allocation),
         :ok <- first_breaking(holdings, &non_negative?/1, :negative_quantity),
         :ok <- check_cash(cash) do
      {:ok, %__MODULE__{holdings: holdings, cash: cash, allocation: allocation}}
    end
  end

  @doc """
  The trades that bring the portfolio back to its allocation at the market's
  current prices, truncating quantities to `precision` decimal places.

  `precision` defaults to the configured share precision (`SHARE_PRECISION`).
  Pure: the portfolio is not changed. Returns `{:error, error}` for E5–E8.
  """
  @spec rebalance(t(), [Stock.t()]) ::
          {:error,
           {:duplicate_stock, any()}
           | {:invalid_precision, any()}
           | {:missing_price, any()}
           | {:non_positive_price, any()}
           | {:quantity_exceeds_precision, any()}}
          | {:ok, [Trade.t()]}
  # @spec rebalance(t(), [Stock.t()], non_neg_integer()) ::
  #         {:ok, [Trade.t()]} | {:error, error()}
  def rebalance(
        %__MODULE__{} = portfolio,
        market,
        precision \\ Portfolio.Config.share_precision()
      ),
      do: Rebalance.trades(portfolio, market, precision)

  @doc """
  The portfolio after applying `trades` one by one, in order (R13–R14).

  A sell takes its quantity from the holding and adds its amount to the cash; a
  buy does the opposite. Returns `{:error, error}` at the first trade that is
  not possible at the moment it is applied (E9–E10).
  """
  @spec apply_trades(t(), [Trade.t()]) :: {:ok, t()} | {:error, error()}
  def apply_trades(%__MODULE__{} = portfolio, trades) do
    Enum.reduce_while(
      trades,
      {:ok, portfolio},
      fn trade, {:ok, current} ->
        case apply_trade(current, trade) do
          {:ok, next} -> {:cont, {:ok, next}}
          error -> {:halt, error}
        end
      end
    )
  end

  # --- Private ----------------------------------------------------------------

  defp apply_trade(portfolio, %Trade{side: :sell, ticker: ticker} = trade) do
    held = Map.get(portfolio.holdings, ticker, Decimal.new(0))

    if Decimal.gt?(trade.quantity, held) do
      {:error, {:not_enough_shares, ticker}}
    else
      {:ok,
       %{
         portfolio
         | holdings:
             put_holding(
               portfolio.holdings,
               ticker,
               Decimal.sub(held, trade.quantity)
             ),
           cash: Decimal.add(portfolio.cash, trade.amount)
       }}
    end
  end

  defp apply_trade(portfolio, %Trade{side: :buy, ticker: ticker} = trade) do
    if Decimal.gt?(trade.amount, portfolio.cash) do
      {:error, {:not_enough_cash, ticker}}
    else
      held = Map.get(portfolio.holdings, ticker, Decimal.new(0))

      {:ok,
       %{
         portfolio
         | holdings:
             put_holding(
               portfolio.holdings,
               ticker,
               Decimal.add(held, trade.quantity)
             ),
           cash: Decimal.sub(portfolio.cash, trade.amount)
       }}
    end
  end

  # R14: a holding that reaches exactly 0 is removed.
  defp put_holding(holdings, ticker, quantity) do
    if Decimal.equal?(quantity, 0),
      do: Map.delete(holdings, ticker),
      else: Map.put(holdings, ticker, quantity)
  end

  # The first entry, by ticker, whose value breaks the rule.
  defp first_breaking(map, valid?, error) do
    map
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.find(fn {_ticker, v} -> not valid?.(v) end)
    |> case do
      nil -> :ok
      {ticker, _value} -> {:error, {error, ticker}}
    end
  end

  # R2: exactly 1, no tolerance.
  defp check_weights_sum(allocation) do
    sum =
      allocation
      |> Map.values()
      |> Enum.reduce(Decimal.new(0), &Decimal.add/2)

    if Decimal.equal?(sum, 1),
      do: :ok,
      else: {:error, {:weights_do_not_sum_to_one, sum}}
  end

  # R4
  defp check_cash(cash) do
    if non_negative?(cash),
      do: :ok,
      else: {:error, :negative_cash}
  end

  # R1
  defp in_unit_range?(weight),
    do: non_negative?(weight) and not Decimal.gt?(weight, 1)

  defp non_negative?(decimal), do: not Decimal.lt?(decimal, 0)
end
