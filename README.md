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

Each step below prints the portfolio as a table with `Portfolio.Report.print/2`: one row per ticker, worked out the way it would be on paper, from what is held and what it is worth now to what it should be worth and the trade between the two. It returns `:ok`; `Portfolio.Report.table/2` gives the same text as `{:ok, text}` instead.

**1. Day 1, before buying anything.** A portfolio of $10,000 in cash, aiming for 25 % AAPL, 25 % MSFT, 50 % NVDA. Weights are fractions that add up to exactly 1.

```elixir
alias Portfolio.Stock
d = &Decimal.new/1

{:ok, portfolio} =
  Portfolio.new(
    holdings: %{},
    cash: d.("10000"),
    allocation: %{"AAPL" => d.("0.25"), "MSFT" => d.("0.25"), "NVDA" => d.("0.50")}
  )

day_1 = [
  %Stock{ticker: "AAPL", price: d.("350")},
  %Stock{ticker: "MSFT", price: d.("525")},
  %Stock{ticker: "NVDA", price: d.("210")}
]

Portfolio.Report.print(portfolio, day_1)
```

```
Ticker  Quantity  Current price  Market value  Actual weight   Weight  Target value  Target quantity  Trade
------  --------  -------------  ------------  -------------  -------  ------------  ---------------  --------------
AAPL           0            350             0          0.00%   25.00%          2500         7.142857  buy   7.142857
MSFT           0            525             0          0.00%   25.00%          2500         4.761904  buy   4.761904
NVDA           0            210             0          0.00%   50.00%          5000        23.809523  buy  23.809523
Cash                                    10000        100.00%
Total                                   10000        100.00%  100.00%         10000

Cash after the trades: 0.00062
```

Everything is cash, so every stock is a buy. The target quantities are truncated to 6 decimal places, and what that leaves unspent, 0.00062, stays as cash.

**2. Day 1, with its trades applied.**

```elixir
{:ok, trades} = Portfolio.rebalance(portfolio, day_1)
{:ok, portfolio} = Portfolio.apply_trades(portfolio, trades)

Portfolio.Report.print(portfolio, day_1)
```

```
Ticker   Quantity  Current price  Market value  Actual weight   Weight  Target value  Target quantity  Trade
------  ---------  -------------  ------------  -------------  -------  ------------  ---------------  -----
AAPL     7.142857            350    2499.99995         25.00%   25.00%          2500         7.142857  -
MSFT     4.761904            525    2499.99960         25.00%   25.00%          2500         4.761904  -
NVDA    23.809523            210    4999.99983         50.00%   50.00%          5000        23.809523  -
Cash                                   0.00062          0.00%
Total                              10000.00000        100.00%  100.00%         10000

Cash after the trades: 0.00062
```

Every holding is at its target quantity, so there is no trade left. Money and quantities are exact: the 0.00062 left over shows as such, never as 0.00.

**3. Day 2, before trading.** Prices move, and NVDA drifts above its half.

```elixir
day_2 = [
  %Stock{ticker: "AAPL", price: d.("310")},
  %Stock{ticker: "MSFT", price: d.("505")},
  %Stock{ticker: "NVDA", price: d.("250")}
]

Portfolio.Report.print(portfolio, day_2)
```

```
Ticker   Quantity  Current price  Market value  Actual weight   Weight  Target value  Target quantity  Trade
------  ---------  -------------  ------------  -------------  -------  ------------  ---------------  -------------
AAPL     7.142857            310    2214.28567         20.95%   25.00%    2642.85714         8.525345  buy  1.382488
MSFT     4.761904            505    2404.76152         22.75%   25.00%    2642.85714         5.233380  buy  0.471476
NVDA    23.809523            250    5952.38075         56.31%   50.00%    5285.71428        21.142857  sell 2.666666
Cash                                   0.00062          0.00%
Total                              10571.42856        100.00%  100.00%   10571.42856

Cash after the trades: 0.00046
```

Percentages are rounded for reading, each on its own, which is why the actual weights add up to 100.01 %. The trades in the last column are the answer the exercise asks for.

**4. Day 2, with its trades applied.** `Portfolio.rebalance/2` gives the trades as data, sells first: they free the cash the buys spend.

```elixir
{:ok, trades} = Portfolio.rebalance(portfolio, day_2)
#=> {:ok,
#=>  [
#=>    %Portfolio.Trade{ticker: "NVDA", side: :sell, quantity: Decimal.new("2.666666"), amount: Decimal.new("666.666500")},
#=>    %Portfolio.Trade{ticker: "AAPL", side: :buy, quantity: Decimal.new("1.382488"), amount: Decimal.new("428.571280")},
#=>    %Portfolio.Trade{ticker: "MSFT", side: :buy, quantity: Decimal.new("0.471476"), amount: Decimal.new("238.095380")}
#=>  ]}

{:ok, portfolio} = Portfolio.apply_trades(portfolio, trades)

Portfolio.Report.print(portfolio, day_2)
```

```
Ticker   Quantity  Current price  Market value  Actual weight   Weight  Target value  Target quantity  Trade
------  ---------  -------------  ------------  -------------  -------  ------------  ---------------  -----
AAPL     8.525345            310    2642.85695         25.00%   25.00%    2642.85714         8.525345  -
MSFT     5.233380            505    2642.85690         25.00%   25.00%    2642.85714         5.233380  -
NVDA    21.142857            250    5285.71425         50.00%   50.00%    5285.71428        21.142857  -
Cash                                   0.00046          0.00%
Total                              10571.42856        100.00%  100.00%   10571.42856

Cash after the trades: 0.00046
```

Back on the allocation, and a rebalance finds nothing more to do:

```elixir
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
