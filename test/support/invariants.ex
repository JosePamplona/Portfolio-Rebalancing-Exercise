defmodule Portfolio.Test.Invariants do
  @moduledoc """
  One checker per invariant INV1–INV7 of `docs/domain-model.md`.

  Each returns `:ok` or `{:error, reason}`. They do their own arithmetic and do
  not call `Portfolio.apply_trades/2`, so a bug in the code under test cannot
  hide itself by also being in its checker. Only INV5 has to call
  `Portfolio.rebalance/3`, because idempotence is a property of the rebalance.
  """

  alias Portfolio.Trade

  @doc "INV1: the portfolio value is the same before and after the trades, exactly."
  def conservation(portfolio, market, trades) do
    prices = prices(market)
    {holdings, cash} = project(portfolio, trades)
    before = value(portfolio.holdings, portfolio.cash, prices)
    after_trades = value(holdings, cash, prices)

    if Decimal.equal?(before, after_trades),
      do: :ok,
      else: {:error, {:value_changed, before, after_trades}}
  end

  @doc "INV2: the cash after the trades is not negative."
  def cash_never_negative(portfolio, trades) do
    {_holdings, cash} = project(portfolio, trades)
    if Decimal.lt?(cash, 0), do: {:error, {:negative_cash, cash}}, else: :ok
  end

  @doc "INV3: the cash after the trades is less than one smallest fraction of each allocated stock."
  def residual_cash(portfolio, market, precision, trades) do
    prices = prices(market)
    {_holdings, cash} = project(portfolio, trades)

    bound =
      portfolio.allocation
      |> Map.keys()
      |> Enum.map(&Decimal.mult(prices[&1], fraction(precision)))
      |> Enum.reduce(Decimal.new(0), &Decimal.add/2)

    if Decimal.lt?(cash, bound), do: :ok, else: {:error, {:residual_too_large, cash, bound}}
  end

  @doc "INV4: no trade, and no holding after the trades, has more decimal places than the precision."
  def respects_precision(portfolio, trades, precision) do
    {holdings, _cash} = project(portfolio, trades)

    quantities =
      Enum.map(trades, &{&1.ticker, &1.quantity}) ++ Enum.to_list(holdings)

    case Enum.find(quantities, fn {_ticker, q} -> not fits?(q, precision) end) do
      nil -> :ok
      {ticker, q} -> {:error, {:too_many_decimals, ticker, q}}
    end
  end

  @doc "INV5: rebalancing the portfolio after the trades, at the same prices, gives no trades."
  def idempotent(portfolio, market, precision, trades) do
    {holdings, cash} = project(portfolio, trades)
    holdings = Map.reject(holdings, fn {_ticker, q} -> Decimal.equal?(q, 0) end)
    rebalanced = %{portfolio | holdings: holdings, cash: cash}

    case Portfolio.rebalance(rebalanced, market, precision) do
      {:ok, []} -> :ok
      other -> {:error, {:not_idempotent, other}}
    end
  end

  @doc "INV6: two runs over the same input, written in different orders, gave the same trades."
  def same_trades(trades_a, trades_b) do
    if Portfolio.Test.Helpers.comparable(trades_a) == Portfolio.Test.Helpers.comparable(trades_b),
      do: :ok,
      else: {:error, {:different_trades, trades_a, trades_b}}
  end

  @doc "INV7: each allocated holding's market value is within one smallest fraction of its target value."
  def allocation_reached(portfolio, market, precision, trades) do
    prices = prices(market)
    {holdings, _cash} = project(portfolio, trades)
    total = value(portfolio.holdings, portfolio.cash, prices)

    off_target =
      Enum.find(portfolio.allocation, fn {ticker, weight} ->
        target = Decimal.mult(total, weight)
        actual = Decimal.mult(Map.get(holdings, ticker, Decimal.new(0)), prices[ticker])
        gap = Decimal.abs(Decimal.sub(target, actual))
        not Decimal.lt?(gap, Decimal.mult(prices[ticker], fraction(precision)))
      end)

    case off_target do
      nil -> :ok
      {ticker, _weight} -> {:error, {:off_target, ticker}}
    end
  end

  # The holdings and the cash after the trades, by plain arithmetic: a sell
  # takes shares and adds its amount, a buy does the opposite. No validation:
  # a broken plan must come through so its invariant can catch it.
  defp project(portfolio, trades) do
    Enum.reduce(trades, {portfolio.holdings, portfolio.cash}, fn %Trade{} = t, {holdings, cash} ->
      held = Map.get(holdings, t.ticker, Decimal.new(0))

      case t.side do
        :sell ->
          {Map.put(holdings, t.ticker, Decimal.sub(held, t.quantity)),
           Decimal.add(cash, t.amount)}

        :buy ->
          {Map.put(holdings, t.ticker, Decimal.add(held, t.quantity)),
           Decimal.sub(cash, t.amount)}
      end
    end)
  end

  defp value(holdings, cash, prices) do
    Enum.reduce(holdings, cash, fn {ticker, q}, acc ->
      Decimal.add(acc, Decimal.mult(q, prices[ticker]))
    end)
  end

  defp prices(market), do: Map.new(market, &{&1.ticker, &1.price})

  defp fraction(precision), do: Decimal.new(1, 1, -precision)

  defp fits?(quantity, precision),
    do: Decimal.equal?(Decimal.round(quantity, precision, :down), quantity)
end
