defmodule Portfolio.Stock do
  @moduledoc """
  A company's share as the market lists it: its ticker and its current price.

  A list of stocks is the *market* a rebalance is priced against.
  """

  @type t :: %__MODULE__{ticker: String.t(), price: Decimal.t()}

  @enforce_keys [:ticker, :price]
  defstruct [:ticker, :price]

  @doc "The last available price of one share."
  @spec current_price(t()) :: Decimal.t()
  def current_price(_stock), do: raise("not implemented")
end
