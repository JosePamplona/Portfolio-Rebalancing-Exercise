defmodule Portfolio.Report do
  @moduledoc """
  A rebalance laid out as a table, for a person to read: *Reading a rebalance*
  in `design/domain-model.md`.

  This is the interface, not the domain. Every number comes from the
  rebalance's own computation (`Portfolio.Rebalance.plan/3`), and the cash
  after from applying its trades, so the table cannot tell a different story.
  Money and quantities are shown exact; weights become percentages here, and
  only here.

      {:ok, table} = Portfolio.Report.table(portfolio, market)
      IO.puts(table)
  """

  alias Portfolio.{Config, Rebalance, Stock, Trade}
  alias Portfolio.Rebalance.Line

  @columns [
    {"Ticker", :left},
    {"Quantity", :right},
    {"Current price", :right},
    {"Market value", :right},
    {"Actual weight", :right},
    {"Weight", :right},
    {"Target value", :right},
    {"Target quantity", :right},
    {"Trade", :left}
  ]

  @separator "  "

  @doc """
  The table of the rebalance of `portfolio` against `market`, or the error the
  rebalance gives (E5–E8). `precision` defaults to the configured one.
  """
  @spec table(Portfolio.t(), [Stock.t()], non_neg_integer()) ::
          {:ok, String.t()} | {:error, Portfolio.error()}
  def table(%Portfolio{} = portfolio, market, precision \\ Config.share_precision()) do
    with {:ok, plan} <- Rebalance.plan(portfolio, market, precision),
         {:ok, after_trades} <- Portfolio.apply_trades(portfolio, plan.trades) do
      {:ok, wide(fn -> render(portfolio, plan, after_trades.cash) end)}
    end
  end

  # --- Private ----------------------------------------------------------------

  defp render(portfolio, plan, cash_after) do
    rows =
      Enum.map(plan.lines, &line_row(&1, plan.value)) ++
        [cash_row(portfolio.cash, plan.value), total_row(plan)]

    table =
      rows
      |> Enum.zip_with(& &1)
      |> Enum.zip_with(@columns, &column/2)
      |> Enum.zip_with(&(&1 |> Enum.join(@separator) |> String.trim_trailing()))

    Enum.join(table ++ ["", "Cash after the trades: #{exact(cash_after)}"], "\n")
  end

  defp line_row(%Line{} = line, value) do
    [
      {:text, line.ticker},
      {:number, line.quantity},
      {:number, line.price},
      {:number, line.market_value},
      {:text, percent(line.market_value, value)},
      {:text, percent(line.weight)},
      {:number, line.target_value},
      {:number, line.target_quantity},
      trade_cell(line.trade)
    ]
  end

  defp cash_row(cash, value) do
    [{:text, "Cash"}, :blank, :blank, {:number, cash}, {:text, percent(cash, value)}] ++
      List.duplicate(:blank, 4)
  end

  defp total_row(plan) do
    [
      {:text, "Total"},
      :blank,
      :blank,
      {:number, plan.value},
      {:text, percent(plan.value, plan.value)},
      {:text, percent(sum(plan.lines, & &1.weight))},
      {:number, sum(plan.lines, & &1.target_value)},
      :blank,
      :blank
    ]
  end

  defp trade_cell(nil), do: :no_trade
  defp trade_cell(%Trade{side: side, quantity: quantity}), do: {:trade, side, quantity}

  # One column as its header, a rule and its cells, all padded to one width.
  defp column(cells, {header, align}) do
    strings = cell_strings(cells)
    width = [header | strings] |> Enum.map(&String.length/1) |> Enum.max()
    Enum.map([header, String.duplicate("-", width) | strings], &pad(&1, width, align))
  end

  # Numbers in a column share its longest decimal part, so the points line up.
  defp cell_strings(cells) do
    scale = cells |> Enum.flat_map(&number/1) |> max_scale()
    quantities = for {:trade, _side, quantity} <- cells, do: quantity
    trade_scale = max_scale(quantities)

    trade_width =
      quantities
      |> Enum.map(&String.length(fixed(&1, trade_scale)))
      |> Enum.max(fn -> 0 end)

    Enum.map(cells, fn
      :blank ->
        ""

      :no_trade ->
        "-"

      {:text, text} ->
        text

      {:number, number} ->
        fixed(number, scale)

      {:trade, side, quantity} ->
        side_name = side |> Atom.to_string() |> String.pad_trailing(4)
        "#{side_name} #{String.pad_leading(fixed(quantity, trade_scale), trade_width)}"
    end)
  end

  defp number({:number, number}), do: [number]
  defp number(_cell), do: []

  defp pad(string, width, :left), do: String.pad_trailing(string, width)
  defp pad(string, width, :right), do: String.pad_leading(string, width)

  # Every decimal the number has, padded with zeros to `scale`: never rounded.
  defp fixed(number, scale),
    do: number |> Decimal.normalize() |> Decimal.round(scale) |> Decimal.to_string(:normal)

  defp exact(number), do: number |> Decimal.normalize() |> Decimal.to_string(:normal)

  defp max_scale(numbers),
    do: numbers |> Enum.map(&scale/1) |> Enum.max(fn -> 0 end)

  defp scale(number), do: max(0, -Decimal.normalize(number).exp)

  # For reading only: rounded half up to two decimals. An actual weight is
  # undefined while the portfolio value is 0.
  defp percent(part, whole) do
    if Decimal.eq?(whole, 0), do: "-", else: percent(Decimal.div(part, whole))
  end

  defp percent(fraction),
    do:
      "#{fraction |> Decimal.mult(100) |> Decimal.round(2, :half_up) |> Decimal.to_string(:normal)}%"

  defp sum(lines, field),
    do: Enum.reduce(lines, Decimal.new(0), &Decimal.add(field.(&1), &2))

  # Enough digits that the sums of the table are never rounded.
  defp wide(fun),
    do: Decimal.Context.with(%{Decimal.Context.get() | precision: 100}, fun)
end
