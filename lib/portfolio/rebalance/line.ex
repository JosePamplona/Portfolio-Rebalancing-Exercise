defmodule Portfolio.Rebalance.Line do
  @moduledoc """
  One ticker's row of a rebalance: every step from what is held to the trade.

  `trade` is `nil` when the holding is already at its target quantity (R11).
  """

  alias Portfolio.Trade

  @enforce_keys [
    :ticker,
    :quantity,
    :price,
    :market_value,
    :weight,
    :target_value,
    :target_quantity,
    :trade
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          ticker: String.t(),
          quantity: Decimal.t(),
          price: Decimal.t(),
          market_value: Decimal.t(),
          weight: Decimal.t(),
          target_value: Decimal.t(),
          target_quantity: Decimal.t(),
          trade: Trade.t() | nil
        }
end
