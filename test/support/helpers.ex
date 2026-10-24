defmodule Portfolio.Test.Helpers do
  @moduledoc "Small builders shared by the tests, so each test reads as its row in `docs/test-plan.md`."

  alias Portfolio.{Stock, Trade}

  @doc "An exact decimal from a string or an integer: `d(\"0.25\")`."
  def d(value) when is_binary(value) or is_integer(value), do: Decimal.new(value)

  @doc "A map of tickers to decimals, from a keyword-like list of strings: `decimals(A: \"1\")`."
  def decimals(pairs), do: Map.new(pairs, fn {ticker, value} -> {to_string(ticker), d(value)} end)

  @doc "A market, from `[{ticker, price}]`."
  def market(pairs), do: Enum.map(pairs, fn {ticker, price} -> stock(ticker, price) end)

  def stock(ticker, price), do: %Stock{ticker: to_string(ticker), price: d(price)}

  @doc "A portfolio built through the public constructor; the test fails if it is rejected."
  def portfolio!(holdings, cash, allocation) do
    {:ok, portfolio} =
      Portfolio.new(holdings: decimals(holdings), cash: d(cash), allocation: decimals(allocation))

    portfolio
  end

  @doc "A trade with its amount written out, as the test plan gives it."
  def trade(side, ticker, quantity, amount) do
    %Trade{ticker: to_string(ticker), side: side, quantity: d(quantity), amount: d(amount)}
  end

  @doc """
  Trades reduced to plain comparable terms. `Decimal` keeps trailing zeros
  (`30.303` and `30.303000` are different structs), so they are normalized first.
  """
  def comparable(trades) do
    Enum.map(trades, fn %Trade{} = t ->
      {t.side, t.ticker, Decimal.normalize(t.quantity), Decimal.normalize(t.amount)}
    end)
  end

  @doc "Whether two decimals are the same number."
  def same?(a, b), do: Decimal.equal?(a, b)
end
