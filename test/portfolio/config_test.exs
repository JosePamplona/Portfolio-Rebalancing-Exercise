defmodule Portfolio.ConfigTest do
  @moduledoc "Configuration: T28 of `docs/test-plan.md`."
  use ExUnit.Case, async: true

  alias Portfolio.Config

  describe "T28 SHARE_PRECISION" do
    test "inside: unset gives the default, 6" do
      assert {:ok, 6} = Config.parse_share_precision(nil)
    end

    test "inside: whole numbers from 0 are accepted" do
      assert {:ok, 0} = Config.parse_share_precision("0")
      assert {:ok, 2} = Config.parse_share_precision("2")
    end

    for raw <- ["", "-1", "2.5", "abc"] do
      @raw raw
      test "outside: #{inspect(raw)} is an error naming the variable" do
        assert {:error, message} = Config.parse_share_precision(@raw)
        assert message =~ "SHARE_PRECISION"
      end
    end
  end
end
