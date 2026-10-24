import Config

# The share precision depends on the broker, so it comes from the environment.
# An invalid value stops the boot here, rather than a rebalance failing later.
case Portfolio.Config.parse_share_precision(System.get_env("SHARE_PRECISION")) do
  {:ok, precision} -> config :portfolio, share_precision: precision
  {:error, message} -> raise message
end
