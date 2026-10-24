defmodule Portfolio.InvariantsTest do
  @moduledoc """
  Invariants: T21–T27 and T29 of `docs/test-plan.md`.

  Each invariant is checked on every scenario S1–S10. Then its checker is run
  against a plan broken on purpose, and must catch it: a checker that never
  fails would let every invariant pass in silence.
  """
  use ExUnit.Case, async: true

  import Portfolio.Test.Helpers

  alias Portfolio.Test.{Invariants, Scenarios}

  # S2's plan, written out, to break one piece at a time.
  defp s2_plan_with(replacements) do
    s2 = Scenarios.fetch("S2")

    trades =
      s2.trades
      |> Enum.map(fn t -> Map.get(replacements, t.ticker, t) end)
      |> Enum.reject(&is_nil/1)

    {s2, trades}
  end

  for id <- Scenarios.ids() do
    @id id

    describe "on #{id}" do
      setup do
        s = Scenarios.fetch(@id)
        {:ok, trades} = Portfolio.rebalance(s.portfolio, s.market, s.precision)
        %{s: s, trades: trades}
      end

      test "T21 INV1 conservation", %{s: s, trades: trades} do
        assert :ok = Invariants.conservation(s.portfolio, s.market, trades)
      end

      test "T22 INV2 cash never negative", %{s: s, trades: trades} do
        assert :ok = Invariants.cash_never_negative(s.portfolio, trades)
      end

      test "T23 INV3 residual cash", %{s: s, trades: trades} do
        assert :ok = Invariants.residual_cash(s.portfolio, s.market, s.precision, trades)
      end

      test "T24 INV4 precision", %{s: s, trades: trades} do
        assert :ok = Invariants.respects_precision(s.portfolio, trades, s.precision)
      end

      test "T25 INV5 idempotence", %{s: s, trades: trades} do
        assert :ok = Invariants.idempotent(s.portfolio, s.market, s.precision, trades)
      end

      test "T26 INV6 input order", %{s: s, trades: trades} do
        reversed = %{
          s.portfolio
          | holdings: s.portfolio.holdings |> Enum.reverse() |> Map.new(),
            allocation: s.portfolio.allocation |> Enum.reverse() |> Map.new()
        }

        assert {:ok, trades_reversed} =
                 Portfolio.rebalance(reversed, Enum.reverse(s.market), s.precision)

        assert :ok = Invariants.same_trades(trades, trades_reversed)
      end

      test "T27 INV7 allocation reached", %{s: s, trades: trades} do
        assert :ok = Invariants.allocation_reached(s.portfolio, s.market, s.precision, trades)
      end

      test "T29 gives the trades and the cash its row names", %{s: s, trades: trades} do
        assert comparable(trades) == comparable(s.trades)

        assert {:ok, after_trades} = Portfolio.apply_trades(s.portfolio, trades)
        assert same?(after_trades.cash, s.cash_after)
      end
    end
  end

  describe "each checker catches a plan broken on purpose" do
    test "T21 INV1: one trade's amount 0.000001 lower" do
      {s, trades} = s2_plan_with(%{"NVDA" => trade(:sell, "NVDA", "2.666666", "666.666499")})

      assert {:error, {:value_changed, _, _}} =
               Invariants.conservation(s.portfolio, s.market, trades)
    end

    test "T22 INV2: AAPL's buy 0.000002 larger, cash ends at -0.000160" do
      {s, trades} = s2_plan_with(%{"AAPL" => trade(:buy, "AAPL", "1.382490", "428.571900")})

      assert {:error, {:negative_cash, cash}} =
               Invariants.cash_never_negative(s.portfolio, trades)

      assert same?(cash, d("-0.000160"))
    end

    test "T23 INV3: without MSFT's buy, 238.095840 stays in cash" do
      {s, trades} = s2_plan_with(%{"MSFT" => nil})

      assert {:error, {:residual_too_large, cash, bound}} =
               Invariants.residual_cash(s.portfolio, s.market, 6, trades)

      assert same?(cash, d("238.095840"))
      assert same?(bound, d("0.001065"))
    end

    test "T24 INV4: AAPL's buy with seven decimals" do
      {s, trades} = s2_plan_with(%{"AAPL" => trade(:buy, "AAPL", "1.3824881", "428.571311")})

      assert {:error, {:too_many_decimals, "AAPL", _}} =
               Invariants.respects_precision(s.portfolio, trades, 6)
    end

    test "T25 INV5: S2 before its trades, passed off as rebalanced" do
      s = Scenarios.fetch("S2")
      assert {:error, {:not_idempotent, _}} = Invariants.idempotent(s.portfolio, s.market, 6, [])
    end

    test "T26 INV6: two different lists of trades" do
      s = Scenarios.fetch("S2")
      assert {:error, {:different_trades, _, _}} = Invariants.same_trades(s.trades, tl(s.trades))
    end

    test "T27 INV7: NVDA's sell 0.000002 smaller leaves it 0.000470 over its target" do
      {s, trades} = s2_plan_with(%{"NVDA" => trade(:sell, "NVDA", "2.666664", "666.666000")})

      assert {:error, {:off_target, "NVDA"}} =
               Invariants.allocation_reached(s.portfolio, s.market, 6, trades)
    end

    test "T27 INV7, the line itself: one fraction smaller stays inside, 0.000220 over" do
      {s, trades} = s2_plan_with(%{"NVDA" => trade(:sell, "NVDA", "2.666665", "666.666250")})
      assert :ok = Invariants.allocation_reached(s.portfolio, s.market, 6, trades)
    end
  end
end
