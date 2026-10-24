defmodule Portfolio do
  @moduledoc """
  The aggregate root: what one investor owns (holdings and cash) and what they
  aim for (an allocation).

  A portfolio can only be built through `new/1`, which enforces R1–R4 of
  `docs/domain-model.md`, so every `%Portfolio{}` that exists is valid.

  Holdings map a ticker to a quantity of shares; the allocation maps a ticker to
  a weight. Prices are not stored here: they come from the market each rebalance
  is computed against (ADR 0002).
  """

  alias Portfolio.{Stock, Trade}

  @type ticker :: String.t()
  @type t :: %__MODULE__{
          holdings: %{ticker() => Decimal.t()},
          cash: Decimal.t(),
          allocation: %{ticker() => Decimal.t()}
        }

  @enforce_keys [:holdings, :cash, :allocation]
  defstruct [:holdings, :cash, :allocation]

  @typedoc "One error per line of the *Errors* table in `docs/domain-model.md`."
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

  Returns `{:error, error}` for the lowest-numbered rule broken (E1–E4).
  """
  @spec new(keyword()) :: {:ok, t()} | {:error, error()}
  def new(_fields), do: raise("not implemented")

  @doc """
  The trades that bring the portfolio back to its allocation at the market's
  current prices, truncating quantities to `precision` decimal places.

  `precision` defaults to the configured share precision (`SHARE_PRECISION`).
  Pure: the portfolio is not changed. Returns `{:error, error}` for E5–E8.
  """
  @spec rebalance(t(), [Stock.t()], non_neg_integer()) :: {:ok, [Trade.t()]} | {:error, error()}
  def rebalance(portfolio, market, precision \\ Portfolio.Config.share_precision())

  def rebalance(_portfolio, _market, _precision), do: raise("not implemented")

  @doc """
  The portfolio after applying `trades` one by one, in order (R13–R14).

  Returns `{:error, error}` at the first trade that is not possible (E9–E10).
  """
  @spec apply_trades(t(), [Trade.t()]) :: {:ok, t()} | {:error, error()}
  def apply_trades(_portfolio, _trades), do: raise("not implemented")
end
