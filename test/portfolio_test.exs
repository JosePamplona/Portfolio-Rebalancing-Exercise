defmodule PortfolioTest do
  @moduledoc "Building a portfolio: T1–T5 of `design/test-plan.md`."
  use ExUnit.Case, async: true

  import Portfolio.Test.Helpers

  # The example in the moduledoc is the worked example, day 2: it must stay true.
  doctest Portfolio

  defp new(holdings, cash, allocation) do
    Portfolio.new(holdings: decimals(holdings), cash: d(cash), allocation: decimals(allocation))
  end

  describe "T1 R1: every weight is between 0 and 1" do
    test "inside: weights of exactly 1 and 0 are accepted" do
      assert {:ok, %Portfolio{} = portfolio} = new([], "0", A: "1", B: "0")
      assert same?(portfolio.allocation["A"], d(1))
      assert same?(portfolio.allocation["B"], d(0))
    end

    test "outside: a weight just above 1 is E1" do
      assert {:error, {:weight_out_of_range, "A"}} = new([], "0", A: "1.000001")
    end

    test "outside: a weight just below 0 is E1, even when the sum is 1" do
      assert {:error, {:weight_out_of_range, "A"}} = new([], "0", A: "-0.000001", B: "1.000001")
    end
  end

  describe "T2 R2: the weights add up to exactly 1" do
    test "inside: thirds written out exactly are accepted" do
      assert {:ok, _} = new([], "0", X: "0.333334", Y: "0.333333", Z: "0.333333")
    end

    test "outside: three equal thirds fall short, and E2 carries the sum found" do
      assert {:error, {:weights_do_not_sum_to_one, sum}} =
               new([], "0", X: "0.333333", Y: "0.333333", Z: "0.333333")

      assert same?(sum, d("0.999999"))
    end

    test "outside: a sum just over 1 is E2" do
      assert {:error, {:weights_do_not_sum_to_one, sum}} = new([], "0", A: "0.5", B: "0.500001")
      assert same?(sum, d("1.000001"))
    end
  end

  describe "T3 R3: no quantity is negative" do
    test "inside: a holding of 0 is accepted" do
      assert {:ok, _} = new([A: "0"], "0", A: "1")
    end

    test "outside: a holding just below 0 is E3" do
      assert {:error, {:negative_quantity, "A"}} = new([A: "-0.000001"], "0", A: "1")
    end
  end

  describe "T4 R4: cash is not negative" do
    test "inside: cash of 0 is accepted" do
      assert {:ok, portfolio} = new([], "0", A: "1")
      assert same?(portfolio.cash, d(0))
    end

    test "outside: cash just below 0 is E4" do
      assert {:error, :negative_cash} = new([], "-0.000001", A: "1")
    end
  end

  describe "T5 error precedence: the lowest-numbered rule, then the first ticker" do
    test "one rule broken gives that rule's error" do
      assert {:error, {:negative_quantity, "A"}} = new([A: "-1"], "0", A: "1")
    end

    test "R1 and R3 broken together give E1" do
      assert {:error, {:weight_out_of_range, "A"}} = new([A: "-1"], "0", A: "1.5")
    end

    test "two tickers out of range give E1 for the first in alphabetical order" do
      assert {:error, {:weight_out_of_range, "A"}} = new([], "0", B: "2", A: "-1")
    end
  end
end
