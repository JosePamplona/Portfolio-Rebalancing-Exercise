defmodule Portfolio.RebalanceTest do
  @moduledoc "Rebalancing: T6–T16 of `design/test-plan.md`."
  use ExUnit.Case, async: true

  import Portfolio.Test.Helpers

  alias Portfolio.Test.Scenarios

  defp rebalance(scenario_id) do
    s = Scenarios.fetch(scenario_id)
    Portfolio.rebalance(s.portfolio, s.market, s.precision)
  end

  describe "T6 R5: every held or allocated ticker has a stock in the market" do
    test "inside: an extra stock nobody holds or allocates is accepted, and gets no trade" do
      portfolio = portfolio!([], "10", A: "1")

      assert {:ok, trades} = Portfolio.rebalance(portfolio, market(A: 10, Z: 5), 6)
      assert Enum.map(trades, & &1.ticker) == ["A"]
    end

    test "outside: a held ticker missing from the market is E5" do
      portfolio = portfolio!([B: "1"], "0", A: "1")
      assert {:error, {:missing_price, "B"}} = Portfolio.rebalance(portfolio, market(A: 10), 6)
    end

    test "outside: an allocated ticker missing from the market is E5" do
      portfolio = portfolio!([], "10", A: "1")
      assert {:error, {:missing_price, "A"}} = Portfolio.rebalance(portfolio, market(Z: 10), 6)
    end
  end

  describe "T7 R6: every current price is greater than 0" do
    test "inside: a price of one millionth is accepted" do
      portfolio = portfolio!([], "1", A: "1")

      assert {:ok, [trade]} = Portfolio.rebalance(portfolio, [stock("A", "0.000001")], 6)
      assert same?(trade.quantity, d(1_000_000))
    end

    test "outside: a price of 0 is E6" do
      portfolio = portfolio!([], "1", A: "1")

      assert {:error, {:non_positive_price, "A"}} =
               Portfolio.rebalance(portfolio, market(A: 0), 6)
    end

    test "outside: a negative price is E6" do
      portfolio = portfolio!([], "1", A: "1")

      assert {:error, {:non_positive_price, "A"}} =
               Portfolio.rebalance(portfolio, market(A: -1), 6)
    end
  end

  describe "T8 R7: the market names each ticker once" do
    test "inside: each ticker once is accepted" do
      portfolio = portfolio!([], "10", A: "1")
      assert {:ok, _} = Portfolio.rebalance(portfolio, market(A: 10, B: 10), 6)
    end

    test "outside: the same ticker twice, even at the same price, is E7" do
      portfolio = portfolio!([], "10", A: "1")

      assert {:error, {:duplicate_stock, "A"}} =
               Portfolio.rebalance(portfolio, market(A: 10, A: 10), 6)
    end
  end

  describe "T9 R8: a valid share precision, and holdings expressible at it" do
    test "inside: precision 0 is accepted" do
      portfolio = portfolio!([], "100", A: "1")
      assert {:ok, _} = Portfolio.rebalance(portfolio, market(A: 30), 0)
    end

    test "inside: a holding with six decimals is accepted at precision 6" do
      portfolio = portfolio!([A: "7.142857"], "0", A: "1")
      assert {:ok, []} = Portfolio.rebalance(portfolio, market(A: 350), 6)
    end

    test "outside: a negative precision is E8" do
      portfolio = portfolio!([], "100", A: "1")

      assert {:error, {:invalid_precision, -1}} =
               Portfolio.rebalance(portfolio, market(A: 30), -1)
    end

    test "outside: a fractional precision is E8" do
      portfolio = portfolio!([], "100", A: "1")

      assert {:error, {:invalid_precision, 2.5}} =
               Portfolio.rebalance(portfolio, market(A: 30), 2.5)
    end

    test "outside: a holding with seven decimals is E8 at precision 6" do
      portfolio = portfolio!([A: "7.1428571"], "0", A: "1")

      assert {:error, {:quantity_exceeds_precision, "A"}} =
               Portfolio.rebalance(portfolio, market(A: 350), 6)
    end

    test "outside: S2's six-decimal holdings are E8 at precision 0" do
      s = Scenarios.fetch("S2")

      assert {:error, {:quantity_exceeds_precision, "AAPL"}} =
               Portfolio.rebalance(s.portfolio, s.market, 0)
    end
  end

  describe "T10 R9: the portfolio value includes the cash" do
    test "cash is spent on the allocation, where ignoring it would give no trade" do
      portfolio = portfolio!([A: "10"], "100", A: "1")

      assert {:ok, trades} = Portfolio.rebalance(portfolio, market(A: 10), 6)
      assert comparable(trades) == comparable([trade(:buy, "A", "10", "100")])
    end
  end

  describe "T11 R10: target quantities are truncated, not rounded" do
    test "MSFT's 2,500 / 525 = 4.7619047… is 4.761904, where rounding would give 4.761905" do
      assert {:ok, trades} = rebalance("S1")
      msft = Enum.find(trades, &(&1.ticker == "MSFT"))

      assert same?(msft.quantity, d("4.761904"))
      refute same?(msft.quantity, d("4.761905"))
    end
  end

  describe "T12 R10: a ticker with no weight is sold whole" do
    test "a ticker held but not allocated (S7)" do
      assert {:ok, [sell | _]} = rebalance("S7")
      assert {sell.side, sell.ticker} == {:sell, "A"}
      assert same?(sell.quantity, d(5))
    end

    test "a ticker allocated at weight 0 (S8)" do
      assert {:ok, [sell | _]} = rebalance("S8")
      assert {sell.side, sell.ticker} == {:sell, "A"}
      assert same?(sell.quantity, d(2))
    end
  end

  describe "T13 R11: a difference of zero is no trade" do
    test "a balanced holding gives an empty list, not a trade of quantity 0" do
      portfolio = portfolio!([A: "1"], "0", A: "1")
      assert {:ok, []} = Portfolio.rebalance(portfolio, market(A: 10), 6)
    end
  end

  describe "T14 R11: the smallest difference is still a trade" do
    test "a difference of one millionth of a share is bought" do
      portfolio = portfolio!([A: "1"], "0.00001", A: "1")

      assert {:ok, trades} = Portfolio.rebalance(portfolio, market(A: 10), 6)
      assert comparable(trades) == comparable([trade(:buy, "A", "0.000001", "0.00001")])
    end
  end

  describe "T15 R12: sells first, then buys, each by ticker" do
    test "S2 gives sell NVDA, then buy AAPL, then buy MSFT" do
      assert {:ok, trades} = rebalance("S2")
      assert Enum.map(trades, &{&1.side, &1.ticker}) == [sell: "NVDA", buy: "AAPL", buy: "MSFT"]
    end
  end

  describe "T16 the worked example of design/domain-model.md" do
    test "day 1 (S1): bought from cash" do
      assert {:ok, trades} = rebalance("S1")

      assert comparable(trades) ==
               comparable([
                 trade(:buy, "AAPL", "7.142857", "2499.999950"),
                 trade(:buy, "MSFT", "4.761904", "2499.999600"),
                 trade(:buy, "NVDA", "23.809523", "4999.999830")
               ])
    end

    test "day 2 (S2): rebalanced after the drift" do
      assert {:ok, trades} = rebalance("S2")

      assert comparable(trades) ==
               comparable([
                 trade(:sell, "NVDA", "2.666666", "666.666500"),
                 trade(:buy, "AAPL", "1.382488", "428.571280"),
                 trade(:buy, "MSFT", "0.471476", "238.095380")
               ])
    end
  end
end
