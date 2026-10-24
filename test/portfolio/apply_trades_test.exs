defmodule Portfolio.ApplyTradesTest do
  @moduledoc "Applying trades: T17–T20 of `docs/test-plan.md`."
  use ExUnit.Case, async: true

  import Portfolio.Test.Helpers

  alias Portfolio.Test.Scenarios

  describe "T17 R13: a sell cannot be larger than the holding" do
    test "inside: selling exactly the whole holding is accepted" do
      portfolio = portfolio!([A: "5"], "0", A: "1")

      assert {:ok, after_trades} =
               Portfolio.apply_trades(portfolio, [trade(:sell, "A", "5", "50")])

      assert same?(after_trades.cash, d(50))
    end

    test "outside: selling one millionth more than the holding is E9" do
      portfolio = portfolio!([A: "5"], "0", A: "1")

      assert {:error, {:not_enough_shares, "A"}} =
               Portfolio.apply_trades(portfolio, [trade(:sell, "A", "5.000001", "50.00001")])
    end
  end

  describe "T18 R13: a buy cannot cost more than the cash" do
    test "inside: a buy that spends exactly all the cash leaves cash 0" do
      portfolio = portfolio!([], "100", A: "1")

      assert {:ok, after_trades} =
               Portfolio.apply_trades(portfolio, [trade(:buy, "A", "100", "100")])

      assert same?(after_trades.cash, d(0))
      assert same?(after_trades.holdings["A"], d(100))
    end

    test "outside: a buy costing one millionth more than the cash is E10" do
      portfolio = portfolio!([], "100", A: "1")

      assert {:error, {:not_enough_cash, "A"}} =
               Portfolio.apply_trades(portfolio, [trade(:buy, "A", "100.000001", "100.000001")])
    end
  end

  describe "T19 R13: trades are applied in the order given" do
    test "inside: S2's trades in their order give S3's portfolio" do
      s2 = Scenarios.fetch("S2")
      s3 = Scenarios.fetch("S3")

      assert {:ok, after_trades} = Portfolio.apply_trades(s2.portfolio, s2.trades)
      assert same?(after_trades.cash, s3.portfolio.cash)

      for {ticker, quantity} <- s3.portfolio.holdings do
        assert same?(after_trades.holdings[ticker], quantity), "holding of #{ticker}"
      end
    end

    test "outside: the same trades with the buys first are E10, the sells have not freed the cash yet" do
      s2 = Scenarios.fetch("S2")
      buys_first = Enum.sort_by(s2.trades, &(&1.side == :sell))

      assert {:error, {:not_enough_cash, "AAPL"}} =
               Portfolio.apply_trades(s2.portfolio, buys_first)
    end
  end

  describe "T20 R14: a holding that reaches 0 is removed" do
    test "a holding sold whole is no longer in the portfolio" do
      portfolio = portfolio!([A: "5", B: "1"], "0", B: "1")

      assert {:ok, after_trades} =
               Portfolio.apply_trades(portfolio, [trade(:sell, "A", "5", "50")])

      refute Map.has_key?(after_trades.holdings, "A")
    end

    test "a holding sold in part stays, with what is left" do
      portfolio = portfolio!([A: "5"], "0", A: "1")

      assert {:ok, after_trades} =
               Portfolio.apply_trades(portfolio, [trade(:sell, "A", "2", "20")])

      assert same?(after_trades.holdings["A"], d(3))
    end
  end
end
