defmodule Portfolio.Test.Scenarios do
  @moduledoc """
  The scenarios S1–S10 of `docs/test-plan.md`, as literal data.

  Every number was computed beforehand with exact decimals, and none is derived
  from the code under test: a scenario that "starts after" another one writes
  its holdings out instead of applying the other one's trades.

  The portfolios are built as structs directly, not through `Portfolio.new/1`,
  so a scenario does not depend on the constructor being right.
  """

  alias Portfolio.Test.Helpers

  @allocation_25_25_50 [AAPL: "0.25", MSFT: "0.25", NVDA: "0.50"]
  @day_1 [AAPL: 350, MSFT: 525, NVDA: 210]
  @day_2 [AAPL: 310, MSFT: 505, NVDA: 250]

  @scenarios [
    %{
      id: "S1",
      name: "from cash",
      holdings: [],
      cash: "10000",
      allocation: @allocation_25_25_50,
      market: @day_1,
      precision: 6,
      trades: [buy: {"AAPL", "7.142857"}, buy: {"MSFT", "4.761904"}, buy: {"NVDA", "23.809523"}],
      cash_after: "0.000620"
    },
    %{
      id: "S2",
      name: "drifted",
      holdings: [AAPL: "7.142857", MSFT: "4.761904", NVDA: "23.809523"],
      cash: "0.000620",
      allocation: @allocation_25_25_50,
      market: @day_2,
      precision: 6,
      trades: [sell: {"NVDA", "2.666666"}, buy: {"AAPL", "1.382488"}, buy: {"MSFT", "0.471476"}],
      cash_after: "0.000460"
    },
    %{
      id: "S3",
      name: "already balanced",
      holdings: [AAPL: "8.525345", MSFT: "5.233380", NVDA: "21.142857"],
      cash: "0.000460",
      allocation: @allocation_25_25_50,
      market: @day_2,
      precision: 6,
      trades: [],
      cash_after: "0.000460"
    },
    %{
      id: "S4",
      name: "whole shares",
      holdings: [AAPL: "7", MSFT: "4", NVDA: "23"],
      cash: "620",
      allocation: @allocation_25_25_50,
      market: @day_2,
      precision: 0,
      trades: [sell: {"NVDA", "2"}, buy: {"AAPL", "1"}, buy: {"MSFT", "1"}],
      cash_after: "305"
    },
    %{
      id: "S5",
      name: "cents of a share",
      holdings: [AAPL: "7.14", MSFT: "4.76", NVDA: "23.80"],
      cash: "4.00",
      allocation: @allocation_25_25_50,
      market: @day_2,
      precision: 2,
      trades: [sell: {"NVDA", "2.66"}, buy: {"AAPL", "1.38"}, buy: {"MSFT", "0.47"}],
      cash_after: "3.85"
    },
    %{
      id: "S6",
      name: "thirds",
      holdings: [],
      cash: "1000",
      allocation: [X: "0.333334", Y: "0.333333", Z: "0.333333"],
      market: [X: 7, Y: 11, Z: 13],
      precision: 6,
      trades: [buy: {"X", "47.619142"}, buy: {"Y", "30.303"}, buy: {"Z", "25.641"}],
      cash_after: "0.000006"
    },
    %{
      id: "S7",
      name: "held, not allocated",
      holdings: [A: "5", B: "3"],
      cash: "0",
      allocation: [B: "1"],
      market: [A: 20, B: 10],
      precision: 6,
      trades: [sell: {"A", "5"}, buy: {"B", "10"}],
      cash_after: "0"
    },
    %{
      id: "S8",
      name: "allocated at weight 0",
      holdings: [A: "2"],
      cash: "0",
      allocation: [A: "0", B: "1"],
      market: [A: 50, B: 25],
      precision: 6,
      trades: [sell: {"A", "2"}, buy: {"B", "4"}],
      cash_after: "0"
    },
    %{
      id: "S9",
      name: "less than one share",
      holdings: [],
      cash: "100",
      allocation: [A: "1"],
      market: [A: 150],
      precision: 0,
      trades: [],
      cash_after: "100"
    },
    %{
      id: "S10",
      name: "empty",
      holdings: [],
      cash: "0",
      allocation: [A: "1"],
      market: [A: 10],
      precision: 6,
      trades: [],
      cash_after: "0"
    }
  ]

  def ids, do: Enum.map(@scenarios, & &1.id)

  @doc "A scenario with its portfolio, market and expected trades built."
  def fetch(id) do
    raw = Enum.find(@scenarios, &(&1.id == id)) || raise "no scenario #{id}"
    market = Helpers.market(raw.market)
    prices = Map.new(market, &{&1.ticker, &1.price})

    %{
      id: raw.id,
      name: raw.name,
      portfolio: %Portfolio{
        holdings: Helpers.decimals(raw.holdings),
        cash: Helpers.d(raw.cash),
        allocation: Helpers.decimals(raw.allocation)
      },
      market: market,
      precision: raw.precision,
      trades:
        Enum.map(raw.trades, fn {side, {ticker, quantity}} ->
          amount = Decimal.mult(Helpers.d(quantity), prices[ticker])
          Helpers.trade(side, ticker, quantity, Decimal.to_string(amount))
        end),
      cash_after: Helpers.d(raw.cash_after)
    }
  end
end
