defmodule Portfolio.Rebalance do
  @moduledoc """
  The rebalance computation: R5–R12 of `design/domain-model.md`, pure.

  Given what the portfolio owns and aims for, and what the market says now:

  1. the portfolio value is the cash plus every holding at its current price (R9);
  2. each ticker's target quantity is its share of that value at its price,
     truncated to the share precision (R10, ADR 0001);
  3. the trade is the target minus what is held: a buy, a sell, or nothing (R11);
  4. sells come first, then buys, each by ticker (R12).

  Whatever truncation leaves unspent stays as cash, so nothing is lost.
  """

  alias Portfolio.Rebalance.Line
  alias Portfolio.{Stock, Trade}

  @typedoc """
  The whole computation: the portfolio value, one line per ticker held or
  allocated (by ticker), and the trades in the order they are to be applied.
  """
  @type plan :: %{value: Decimal.t(), lines: [Line.t()], trades: [Trade.t()]}

  @doc "Validates the inputs (E5–E8) and computes the trades."
  @spec trades(Portfolio.t(), [Stock.t()], non_neg_integer()) ::
          {:ok, [Trade.t()]} | {:error, Portfolio.error()}
  def trades(%Portfolio{} = portfolio, market, precision) do
    with {:ok, plan} <- plan(portfolio, market, precision), do: {:ok, plan.trades}
  end

  @doc """
  Validates the inputs (E5–E8) and computes every step on the way to the
  trades, for whoever needs to show how they were reached.
  """
  @spec plan(Portfolio.t(), [Stock.t()], non_neg_integer()) ::
          {:ok, plan()} | {:error, Portfolio.error()}
  def plan(%Portfolio{} = portfolio, market, precision) do
    with :ok <- check_market(portfolio, market),
         :ok <- check_precision(portfolio, precision) do
      {:ok, exactly(fn -> compute(portfolio, prices(market), precision) end)}
    end
  end

  # --- Private ----------------------------------------------------------------

  # R5, R6, R7, in that order: the lowest-numbered rule is the error reported.
  defp check_market(portfolio, market) do
    listed = MapSet.new(market, & &1.ticker)

    cond do
      ticker = Enum.find(tickers(portfolio), &(not MapSet.member?(listed, &1))) ->
        {:error, {:missing_price, ticker}}

      stock =
          market
          |> Enum.sort_by(& &1.ticker)
          |> Enum.find(&(not positive?(Stock.current_price(&1)))) ->
        {:error, {:non_positive_price, stock.ticker}}

      ticker = duplicate(market) ->
        {:error, {:duplicate_stock, ticker}}

      true ->
        :ok
    end
  end

  # R8: a whole number from 0, and every holding expressible at it, so a trade
  # can always sell a whole holding.
  defp check_precision(_portfolio, precision) when not is_integer(precision) or precision < 0,
    do: {:error, {:invalid_precision, precision}}

  defp check_precision(portfolio, precision) do
    case Enum.find(sorted(portfolio.holdings), fn {_ticker, q} -> not fits?(q, precision) end) do
      nil -> :ok
      {ticker, _quantity} -> {:error, {:quantity_exceeds_precision, ticker}}
    end
  end

  defp compute(portfolio, prices, precision) do
    value = portfolio_value(portfolio, prices)

    lines =
      portfolio
      |> tickers()
      |> Enum.map(&line(portfolio, &1, prices[&1], value, precision))

    {sells, buys} =
      lines
      |> Enum.map(& &1.trade)
      |> Enum.reject(&is_nil/1)
      |> Enum.split_with(&(&1.side == :sell))

    %{value: value, lines: lines, trades: sells ++ buys}
  end

  # R10 and R11 for one ticker; a ticker with no weight gets a target of 0.
  defp line(portfolio, ticker, price, value, precision) do
    quantity = held(portfolio, ticker)
    weight = Map.get(portfolio.allocation, ticker, zero())
    target_value = Decimal.mult(value, weight)
    target = target_quantity(target_value, price, precision)

    %Line{
      ticker: ticker,
      quantity: quantity,
      price: price,
      market_value: Decimal.mult(quantity, price),
      weight: weight,
      target_value: target_value,
      target_quantity: target,
      trade: trade(ticker, Decimal.sub(target, quantity), price)
    }
  end

  # R9
  defp portfolio_value(portfolio, prices) do
    Enum.reduce(portfolio.holdings, portfolio.cash, fn {ticker, quantity}, total ->
      Decimal.add(total, Decimal.mult(quantity, prices[ticker]))
    end)
  end

  # R10. The quotient is truncated with an integer division at the scale of the
  # precision, never by rounding a decimal quotient: a quotient rounded to some
  # working precision first could land on the wrong side of a boundary
  # (1.9999999… shown as 2.000000).
  defp target_quantity(target_value, price, precision) do
    smallest = Decimal.new(1, 1, -precision)
    whole_fractions = Decimal.div_int(target_value, Decimal.mult(price, smallest))
    Decimal.mult(whole_fractions, smallest)
  end

  # R11: zero is no trade at all, not a trade of quantity 0.
  defp trade(ticker, difference, price) do
    case Decimal.compare(difference, 0) do
      :eq -> nil
      :gt -> build_trade(ticker, :buy, difference, price)
      :lt -> build_trade(ticker, :sell, Decimal.abs(difference), price)
    end
  end

  defp build_trade(ticker, side, quantity, price),
    do: %Trade{
      ticker: ticker,
      side: side,
      quantity: quantity,
      amount: Decimal.mult(quantity, price)
    }

  # Every ticker held or allocated, in alphabetical order: the order of the
  # input never shows in the output (R12, INV6).
  defp tickers(portfolio) do
    (Map.keys(portfolio.holdings) ++ Map.keys(portfolio.allocation))
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp prices(market), do: Map.new(market, &{&1.ticker, Stock.current_price(&1)})

  defp duplicate(market) do
    market
    |> Enum.frequencies_by(& &1.ticker)
    |> Enum.filter(fn {_ticker, count} -> count > 1 end)
    |> Enum.map(fn {ticker, _count} -> ticker end)
    |> Enum.min(fn -> nil end)
  end

  defp held(portfolio, ticker), do: Map.get(portfolio.holdings, ticker, zero())

  defp sorted(map), do: Enum.sort_by(map, fn {ticker, _value} -> ticker end)

  defp fits?(quantity, precision),
    do: Decimal.equal?(Decimal.round(quantity, precision, :down), quantity)

  defp positive?(decimal), do: Decimal.gt?(decimal, 0)

  defp zero, do: Decimal.new(0)

  # Runs the computation with enough digits that nothing is ever rounded, and
  # with :inexact trapped: if an operation ever had to round, it raises instead
  # of losing a fraction in silence.
  defp exactly(fun) do
    context = %{
      Decimal.Context.get()
      | precision: 100,
        traps: [:inexact | Decimal.Context.get().traps]
    }

    Decimal.Context.with(context, fun)
  end
end
