# Portfolio rebalancing

This repository is the solution to a technical exercise: build a `Portfolio` with a collection of stocks and a target allocation, and a method that says which stocks to sell and which to buy to bring it back to that allocation.

A portfolio holds some stocks and some cash, and aims for an allocation: say 25 % AAPL, 25 % MSFT, 50 % NVDA. Prices move, quantities do not, and the real weights drift away from the allocation. This module computes the trades that bring the portfolio back to it, without inventing or losing a cent or a fraction of a share.

The answer to the exercise is `Portfolio.rebalance/3` ([`lib/portfolio.ex`](lib/portfolio.ex)), computed in [`lib/portfolio/rebalance.ex`](lib/portfolio/rebalance.ex).

## Reading order

1. [`CONTEXT.md`](CONTEXT.md): the domain's language. One word per concept, and the synonyms it rules out.
2. [`design/domain-model.md`](design/domain-model.md): the building blocks, the numbered rules and invariants every test cites, a worked example with exact numbers, and the structure.
3. [`design/adr/`](design/adr/): the decisions a reader could wonder about.
   - [0001](design/adr/0001-truncate-to-share-precision.md): quantities are truncated to the share precision, and the rest stays as cash.
   - [0002](design/adr/0002-prices-live-in-the-market.md): prices live in the market, not in the portfolio.
   - [0003](design/adr/0003-a-library-not-an-application.md): a library, not an application.

## Running it

```sh
mix setup   # dependencies, and the pre-commit hook: format, Credo, Dialyzer
mix test
```

Erlang and Elixir versions are pinned in `.tool-versions` (asdf). CI runs the tests on every push to `main`.

## Trying it in IEx

Start a shell with the project loaded:

```sh
iex -S mix
```

**1. A portfolio of $10,000 in cash**, aiming for 25 % AAPL, 25 % MSFT, 50 % NVDA. Weights are fractions that add up to exactly 1.

```elixir
alias Portfolio.Stock
d = &Decimal.new/1

{:ok, portfolio} =
  Portfolio.new(
    holdings: %{},
    cash: d.("10000"),
    allocation: %{"AAPL" => d.("0.25"), "MSFT" => d.("0.25"), "NVDA" => d.("0.50")}
  )
```

**2. Day 1: buy into the allocation** at today's prices, and apply the trades.

```elixir
day_1 = [
  %Stock{ticker: "AAPL", price: d.("350")},
  %Stock{ticker: "MSFT", price: d.("525")},
  %Stock{ticker: "NVDA", price: d.("210")}
]

{:ok, trades} = Portfolio.rebalance(portfolio, day_1)
{:ok, portfolio} = Portfolio.apply_trades(portfolio, trades)
portfolio.cash
#=> Decimal.new("0.000620")
```

The quantities were truncated to 6 decimal places (7.142857 AAPL, 4.761904 MSFT, 23.809523 NVDA), and what that left unspent stayed as cash.

**3. Day 2: prices move**, NVDA drifts above its half, and the rebalance says what to do about it.

```elixir
day_2 = [
  %Stock{ticker: "AAPL", price: d.("310")},
  %Stock{ticker: "MSFT", price: d.("505")},
  %Stock{ticker: "NVDA", price: d.("250")}
]

{:ok, trades} = Portfolio.rebalance(portfolio, day_2)
#=> {:ok,
#=>  [
#=>    %Portfolio.Trade{ticker: "NVDA", side: :sell, quantity: Decimal.new("2.666666"), amount: Decimal.new("666.666500")},
#=>    %Portfolio.Trade{ticker: "AAPL", side: :buy, quantity: Decimal.new("1.382488"), amount: Decimal.new("428.571280")},
#=>    %Portfolio.Trade{ticker: "MSFT", side: :buy, quantity: Decimal.new("0.471476"), amount: Decimal.new("238.095380")}
#=>  ]}
```

Sells come first: they free the cash the buys spend.

**4. Apply them, and rebalancing again finds nothing to do.**

```elixir
{:ok, portfolio} = Portfolio.apply_trades(portfolio, trades)
portfolio.cash
#=> Decimal.new("0.000460")

Portfolio.rebalance(portfolio, day_2)
#=> {:ok, []}
```

**5. Invalid input comes back as an error naming the rule**, never as an exception.

```elixir
Portfolio.new(
  holdings: %{},
  cash: d.("0"),
  allocation: %{"A" => d.("0.333333"), "B" => d.("0.333333"), "C" => d.("0.333333")}
)
#=> {:error, {:weights_do_not_sum_to_one, Decimal.new("0.999999")}}

Portfolio.rebalance(portfolio, tl(day_2))   # a market without AAPL
#=> {:error, {:missing_price, "AAPL"}}
```

**6. Another share precision**: pass it as the third argument (`Portfolio.rebalance(portfolio, day_1, 0)` for whole shares), or set it for the whole session with `SHARE_PRECISION=2 iex -S mix`.

The errors, rules and invariants behind each of these are in [`design/domain-model.md`](design/domain-model.md).

## How it was built

Domain first, then tests, then code: the documentation above came before any line of Elixir, and every test names the rule or invariant it proves.

An LLM (Claude) was used as a pair throughout, as the exercise allows. The conversations will be shared in [`design/llm-conversations/`](design/llm-conversations/).
