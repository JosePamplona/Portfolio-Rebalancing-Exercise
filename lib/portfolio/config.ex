defmodule Portfolio.Config do
  @moduledoc """
  The share precision, configured through `SHARE_PRECISION`.

  `config/runtime.exs` reads the environment once, at boot, and hands the raw
  value to `parse_share_precision/1`. The domain never reads the environment:
  `share_precision/0` returns what was configured.
  """

  @default_share_precision 6

  @doc "The configured share precision; #{@default_share_precision} if none was configured."
  @spec share_precision() :: non_neg_integer()
  def share_precision do
    Application.get_env(:portfolio, :share_precision, @default_share_precision)
  end

  @doc """
  Parses the raw value of `SHARE_PRECISION`: `nil` (unset) gives the default.

  The error is a message naming the variable, for the boot to stop with.
  """
  @spec parse_share_precision(String.t() | nil) ::
          {:ok, non_neg_integer()} | {:error, String.t()}
  def parse_share_precision(nil), do: {:ok, @default_share_precision}

  def parse_share_precision(raw) when is_binary(raw) do
    # Integer.parse/1 alone would read "2.5" as 2: the whole string must be the number.
    case Integer.parse(raw) do
      {precision, ""} when precision >= 0 ->
        {:ok, precision}

      _ ->
        {
          :error,
          "SHARE_PRECISION must be a whole number, 0 or more; got #{inspect(raw)}"
        }
    end
  end
end
