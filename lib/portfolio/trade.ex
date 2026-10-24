defmodule Portfolio.Trade do
  @moduledoc """
  One instruction to buy or sell a quantity of one stock at its current price.

  `quantity` is always positive; `side` says which way it goes. `amount` is
  `quantity × current price`, exact.
  """

  @type side :: :buy | :sell
  @type t :: %__MODULE__{
          ticker: String.t(),
          side: side(),
          quantity: Decimal.t(),
          amount: Decimal.t()
        }

  @enforce_keys [:ticker, :side, :quantity, :amount]
  defstruct [:ticker, :side, :quantity, :amount]
end
