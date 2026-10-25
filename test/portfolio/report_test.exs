defmodule Portfolio.ReportTest do
  @moduledoc "Reading a rebalance: T30–T33 of `design/test-plan.md`."
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO
  import Portfolio.Test.Helpers

  alias Portfolio.Report
  alias Portfolio.Test.Scenarios

  defp table(scenario_id) do
    s = Scenarios.fetch(scenario_id)
    Report.table(s.portfolio, s.market, s.precision)
  end

  # A heredoc ends in a newline; the table does not, so IO.puts prints it whole.
  defp text(heredoc), do: String.trim_trailing(heredoc, "\n")

  describe "T30: the table is the rebalance's computation" do
    test "the case: S2 gives the table of the domain model" do
      assert table("S2") ==
               {:ok,
                text("""
                Ticker   Quantity  Current price  Market value  Actual weight   Weight  Target value  Target quantity  Trade
                ------  ---------  -------------  ------------  -------------  -------  ------------  ---------------  -------------
                AAPL     7.142857            310    2214.28567         20.95%   25.00%    2642.85714         8.525345  buy  1.382488
                MSFT     4.761904            505    2404.76152         22.75%   25.00%    2642.85714         5.233380  buy  0.471476
                NVDA    23.809523            250    5952.38075         56.31%   50.00%    5285.71428        21.142857  sell 2.666666
                Cash                                   0.00062          0.00%
                Total                              10571.42856        100.00%  100.00%   10571.42856

                Cash after the trades: 0.00046
                """)}
    end

    test "ruled out: a market missing AAPL gives the rebalance's error, and no table" do
      s = Scenarios.fetch("S2")
      market = Enum.reject(s.market, &(&1.ticker == "AAPL"))

      assert Report.table(s.portfolio, market, 6) == {:error, {:missing_price, "AAPL"}}
      assert Report.table(s.portfolio, market, 6) == Portfolio.rebalance(s.portfolio, market, 6)
    end
  end

  describe "T31: money is shown exact" do
    test "the case: S1's residual cash is shown as 0.00062, not rounded to cents" do
      assert table("S1") ==
               {:ok,
                text("""
                Ticker  Quantity  Current price  Market value  Actual weight   Weight  Target value  Target quantity  Trade
                ------  --------  -------------  ------------  -------------  -------  ------------  ---------------  --------------
                AAPL           0            350             0          0.00%   25.00%          2500         7.142857  buy   7.142857
                MSFT           0            525             0          0.00%   25.00%          2500         4.761904  buy   4.761904
                NVDA           0            210             0          0.00%   50.00%          5000        23.809523  buy  23.809523
                Cash                                    10000        100.00%
                Total                                   10000        100.00%  100.00%         10000

                Cash after the trades: 0.00062
                """)}
    end
  end

  describe "T32: the edges of the table" do
    test "the case: S7's A, held and not allocated, stays in the table at weight 0" do
      assert table("S7") ==
               {:ok,
                text("""
                Ticker  Quantity  Current price  Market value  Actual weight   Weight  Target value  Target quantity  Trade
                ------  --------  -------------  ------------  -------------  -------  ------------  ---------------  -------
                A              5             20           100         76.92%    0.00%             0                0  sell  5
                B              3             10            30         23.08%  100.00%           130               13  buy  10
                Cash                                        0          0.00%
                Total                                     130        100.00%  100.00%           130

                Cash after the trades: 0
                """)}
    end

    test "the case: S10, portfolio value 0, shows every actual weight as -" do
      assert table("S10") ==
               {:ok,
                text("""
                Ticker  Quantity  Current price  Market value  Actual weight   Weight  Target value  Target quantity  Trade
                ------  --------  -------------  ------------  -------------  -------  ------------  ---------------  -----
                A              0             10             0              -  100.00%             0                0  -
                Cash                                        0              -
                Total                                       0              -  100.00%             0

                Cash after the trades: 0
                """)}
    end

    test "the precision defaults to the configured one" do
      portfolio = portfolio!([], "10", A: "1")
      assert Report.table(portfolio, market(A: 3)) == Report.table(portfolio, market(A: 3), 6)
    end
  end

  describe "T33: printing the table" do
    test "the case: S2 is written to the console exactly as table/3 gives it, and :ok" do
      s = Scenarios.fetch("S2")
      {:ok, table} = Report.table(s.portfolio, s.market, s.precision)

      {result, output} =
        with_io(fn -> Report.print(s.portfolio, s.market, s.precision) end)

      assert result == :ok
      assert output == table <> "\n"
    end

    test "ruled out: a market missing AAPL prints nothing, and gives the rebalance's error" do
      s = Scenarios.fetch("S2")
      market = Enum.reject(s.market, &(&1.ticker == "AAPL"))

      assert {{:error, {:missing_price, "AAPL"}}, ""} =
               with_io(fn -> Report.print(s.portfolio, market, 6) end)
    end

    test "the precision defaults to the configured one" do
      portfolio = portfolio!([], "10", A: "1")

      assert capture_io(fn -> Report.print(portfolio, market(A: 3)) end) ==
               capture_io(fn -> Report.print(portfolio, market(A: 3), 6) end)
    end
  end
end
