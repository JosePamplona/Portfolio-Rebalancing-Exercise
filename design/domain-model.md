# Domain model

How the portfolio domain is shaped, which rules it follows and which invariants every rebalance must keep. The words are defined in [`CONTEXT.md`](../CONTEXT.md); the decisions behind the less obvious choices are in [`adr/`](adr/).

Rules are numbered (`R1`…), invariants too (`INV1`…), and so are errors (`E1`…). Each test names the rule, invariant or error it proves, so every line here is covered by at least one test, and every test traces back to a line here.

## The problem

An investor owns some shares of some stocks, plus some cash, and has decided how they want their money spread: an **allocation**, say 25 % AAPL, 25 % MSFT, 50 % NVDA. They buy according to it. Then prices move and quantities do not, so the real weights **drift** away from the allocation. A **rebalance** says what to sell and what to buy to get back to it, at today's prices, without inventing or losing a cent or a fraction of a share.

## Building blocks

| Concept | DDD role | Made of | Notes |
|---|---|---|---|
| **Portfolio** | Aggregate root | holdings, cash, allocation | The only entry point. It guards its own consistency when built (`R1`–`R4`). |
| **Holding** | Value, inside the portfolio | ticker → quantity | A number of shares, never money. |
| **Allocation** | Value, inside the portfolio | ticker → weight | Weights in `[0, 1]`, adding up to exactly 1. |
| **Stock** | Value, outside the portfolio | ticker, current price | What the market says now. Exposes `current_price/1`. |
| **Market** | Value, outside the portfolio | a set of stocks | What a rebalance is priced against. Prices live here, not in the portfolio ([ADR 0002](adr/0002-prices-live-in-the-market.md)). |
| **Trade** | Value, the result | ticker, side (buy/sell), quantity, amount | `amount = quantity × current price`, exact. |

All money, prices, quantities and weights are exact decimals. No floating point anywhere.

## Operations

| Operation | Takes | Gives | Role |
|---|---|---|---|
| Build a portfolio | holdings, cash, allocation | the portfolio, or an error (`E1`–`E4`) | Enforces `R1`–`R4` once, so every portfolio that exists is valid. |
| Rebalance | a portfolio, a market, a share precision (the configured one unless given, see [Configuration](#configuration)) | the list of trades, or an error (`E5`–`E8`) | The question the exercise asks. Pure: it changes nothing. |
| Apply trades | a portfolio, a list of trades | the portfolio after them, or an error (`E9`–`E10`) | Lets the tests check that a rebalance really does what it says (`INV1`, `INV5`). |
| Show the rebalance as a table | the same as a rebalance | a text table of the computation (or printed to the console), or the rebalance's error | For a person to read, not part of the domain: see [Reading a rebalance](#reading-a-rebalance). |

## Rules

### A valid portfolio

- **R1**: Every weight is between 0 and 1, both included.
- **R2**: The weights add up to **exactly** 1. An allocation of thirds must be written out exactly, for instance `0.333334 + 0.333333 + 0.333333`. Nothing is rounded for the investor. Showing and taking weights as percentages is the interface's job; the domain only knows fractions.
- **R3**: No quantity is negative.
- **R4**: Cash is not negative.

### A valid rebalance

- **R5**: Every ticker in the holdings or in the allocation has a stock in the market.
- **R6**: Every current price is greater than 0.
- **R7**: The market names each ticker once.
- **R8**: The share precision is a whole number, 0 or more. Every held quantity is expressible at that precision, so a trade can always sell a whole holding.

### How a rebalance is computed

- **R9**: The **portfolio value** is the cash plus the market value of every holding.
- **R10**: The **target quantity** of each ticker is its weight times the portfolio value, divided by its current price, **truncated** (rounded toward zero) to the share precision ([ADR 0001](adr/0001-truncate-to-share-precision.md)). A ticker held but not in the allocation has weight 0, so its target is 0: it is sold whole.
- **R11**: Each ticker's trade is its target quantity minus its held quantity: a positive difference is a buy, a negative one a sell, and zero is no trade at all.
- **R12**: The trades come sells first, then buys, each group ordered by ticker. The order does not depend on how the input was written, and selling first frees the cash the buys spend.

### How trades are applied

- **R13**: Trades are applied one by one, in the order given. A sell takes its quantity from the holding and adds its amount to the cash; a buy does the opposite. Each one must be possible at the moment it is applied.
- **R14**: A holding that reaches exactly 0 is removed from the portfolio.

## Invariants

What every rebalance keeps, whatever the input. Each is a test run against every scenario, not only against one example.

- **INV1, Conservation**: the portfolio value before the rebalance equals the portfolio value after applying its trades, at the same prices. It is an exact equality, with no tolerance.
- **INV2, Cash never goes negative**: the buys cost at most the cash plus what the sells bring in.
- **INV3, Residual cash is only the truncation**: the cash after the rebalance is less than the sum, over the allocated tickers, of one smallest fraction of each (`current price × 10⁻ᴺ`).
- **INV4, Quantities respect the precision**: no trade, and no holding after the trades, has more decimal places than the share precision.
- **INV5, Idempotence**: rebalancing a portfolio that was just rebalanced, at the same prices, gives no trades.
- **INV6, Input order is irrelevant**: the same holdings, allocation and market, written in any order, give the same trades.
- **INV7, Allocation reached**: after the trades, each allocated ticker's market value is within one smallest fraction of its target value (`weight × portfolio value`).

## Errors

Every error comes back as a value naming the rule it breaks and the offending ticker. Nothing raises. When an input breaks several rules, the error reported is the one for the lowest-numbered rule, and within it, for the first ticker in alphabetical order, so the same input always gives the same error.

| Error | Rule | When | Value |
|---|---|---|---|
| **E1** weight out of range | R1 | a weight below 0 or above 1 | `{:weight_out_of_range, ticker}` |
| **E2** weights do not add up to 1 | R2 | the sum is not exactly 1 | `{:weights_do_not_sum_to_one, sum}` |
| **E3** negative quantity | R3 | a holding below 0 | `{:negative_quantity, ticker}` |
| **E4** negative cash | R4 | cash below 0 | `:negative_cash` |
| **E5** missing price | R5 | a held or allocated ticker absent from the market | `{:missing_price, ticker}` |
| **E6** non-positive price | R6 | a current price of 0 or less | `{:non_positive_price, ticker}` |
| **E7** duplicate stock | R7 | the market names a ticker twice | `{:duplicate_stock, ticker}` |
| **E8** precision | R8 | an invalid share precision | `{:invalid_precision, precision}` |
| | | a held quantity finer than the precision | `{:quantity_exceeds_precision, ticker}` |
| **E9** not enough shares | R13 | a sell larger than the holding at that point | `{:not_enough_shares, ticker}` |
| **E10** not enough cash | R13 | a buy costing more than the cash at that point | `{:not_enough_cash, ticker}` |

## Worked example

The case from the exercise, computed with exact decimals at the default share precision of 6. It is also the first golden test.

**Day 1.** $10,000 in cash, allocation 25 % AAPL, 25 % MSFT, 50 % NVDA. Prices: AAPL 350, MSFT 525, NVDA 210. The rebalance buys from nothing:

| Ticker | Target value | ÷ price | Truncated quantity | Cost |
|---|---:|---:|---:|---:|
| AAPL | 2,500 | 7.142857142… | 7.142857 | 2,499.999950 |
| MSFT | 2,500 | 4.761904761… | 4.761904 | 2,499.999600 |
| NVDA | 5,000 | 23.809523809… | 23.809523 | 4,999.999830 |

Residual cash: 10,000 − 9,999.999380 = **0.000620**.

**Day 2.** Prices move to AAPL 310, MSFT 505, NVDA 250. The holdings drift:

| Ticker | Quantity | Market value | Actual weight | Allocated |
|---|---:|---:|---:|---:|
| AAPL | 7.142857 | 2,214.285670 | 20.9459 % | 25 % |
| MSFT | 4.761904 | 2,404.761520 | 22.7477 % | 25 % |
| NVDA | 23.809523 | 5,952.380750 | 56.3063 % | 50 % |
| Cash | | 0.000620 | | |

Portfolio value: **10,571.428560**. The rebalance gives:

| Trade | Quantity | Amount | Quantity after | Market value after |
|---|---:|---:|---:|---:|
| sell NVDA | 2.666666 | 666.666500 | 21.142857 | 5,285.714250 |
| buy AAPL | 1.382488 | 428.571280 | 8.525345 | 2,642.856950 |
| buy MSFT | 0.471476 | 238.095380 | 5.233380 | 2,642.856900 |

Cash after: 0.000620 + 666.666500 − 428.571280 − 238.095380 = **0.000460**, less than the bound of `INV3`: (310 + 505 + 250) × 10⁻⁶ = 0.001065. Positions plus cash add up to 10,571.428560 again (`INV1`).

## Reading a rebalance

A list of trades says what to do, not why. For a demonstration, `Portfolio.Report.table/3` lays the computation out as a table, one row per ticker, the way it would be worked out on paper:

| Column | What it is | Rule |
|---|---|---|
| Quantity | what is held | |
| Current price | from the market | |
| Market value | quantity × current price | `R9` |
| Actual weight | market value ÷ portfolio value | |
| Weight | from the allocation, 0 if the ticker is not allocated | `R10` |
| Target value | portfolio value × weight | `R10` |
| Target quantity | target value ÷ current price, truncated | `R10` |
| Trade | target quantity − quantity, as a buy or a sell | `R11` |

A *Cash* row and a *Total* row (the portfolio value) close it, and a last line gives the cash after the trades. For the worked example, on day 2:

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

The table is the interface, not the domain, so it lives apart from the aggregate. Three things keep it from telling a different story from the rebalance:

- **One computation.** The rebalance computes every column on its way to the trades, and the table reads them from it (`Portfolio.Rebalance.plan/3`). There is no second copy of the arithmetic that could disagree. The cash after comes from applying the trades.
- **Money and quantities exact.** They are shown with every decimal they have, never rounded to cents: rounding would show the residual cash 0.00062 as 0.00, and hide the very thing the table is there to show. Each column is padded with zeros to its longest decimal part, so the points line up; trailing zeros add no digit that is not already there.
- **Percentages for reading only.** Weights become percentages here, and only here, rounded half up to two decimals. Each one is rounded on its own, so a column can add up to a hair off its total: day 2's actual weights show 100.01 %. An actual weight is undefined while the portfolio value is 0, and shows as `-`.

An invalid input gives the same error the rebalance gives, and no table.

`Portfolio.Report.print/3` takes the same arguments, writes the table to the console and returns `:ok`, or returns the error and writes nothing. It is a separate function, not an option of `table/3`, so neither one's return depends on a flag: `table/3` and `print/3` are to each other what `inspect/2` is to `IO.inspect/2`. Printing needs nothing but `IO.puts/1`, so the table takes no dependency ([Hex](https://hex.pm) has `table_rex`, but the alignment that matters here, decimal points lined up without rounding, would still be ours).

## Configuration

The share precision depends on the broker, so it is configured, not written in the code.

| Variable | Default | Accepts |
|---|---|---|
| `SHARE_PRECISION` | `6` | a whole number, 0 or more |

The environment is read once, at boot, in `config/runtime.exs`, which hands the raw value to `Portfolio.Config` to parse and check. An invalid value stops the boot with a message naming the variable, rather than letting a rebalance fail later. The domain never reads the environment itself: a rebalance takes the precision as a parameter, defaulting to the configured value. That keeps it pure, and lets the tests pass each precision explicitly.

## Structure

A plain Elixir library, no web layer ([ADR 0003](adr/0003-a-library-not-an-application.md)). One module per building block, and the computation as a pure function apart from the aggregate:

```
config/
└── runtime.exs               # reads SHARE_PRECISION, validates it, defaults to 6
lib/
├── portfolio.ex              # Portfolio, the aggregate root: build, rebalance, apply trades
└── portfolio/
    ├── stock.ex              # Stock: ticker + current price, current_price/1
    ├── trade.ex              # Trade: ticker, side, quantity, amount
    ├── rebalance.ex          # the computation of R9–R12, pure
    ├── rebalance/line.ex     # one ticker's row of that computation
    ├── report.ex             # the computation as a table, for a person to read
    └── config.ex             # parses and checks SHARE_PRECISION
test/
├── support/
│   ├── scenarios.ex          # the named scenarios the invariants run over
│   └── invariants.ex         # one checker per invariant
├── portfolio_test.exs        # building a portfolio: R1–R4, E1–E4
├── portfolio/rebalance_test.exs   # R5–R12, E5–E8, the worked example
├── portfolio/apply_trades_test.exs  # R13–R14, E9–E10
├── portfolio/invariants_test.exs  # INV1–INV7 over every scenario, and each checker against a broken plan
├── portfolio/report_test.exs # the table
└── portfolio/config_test.exs # SHARE_PRECISION
```

The test plan, every test and the side of the line it stands on, is in [`test-plan.md`](test-plan.md).

Its only dependency is `decimal`, for exact arithmetic.

## Testing

A test that only shows the happy side of a rule does not say where the rule stops. So every test comes as a pair, and what the pair is depends on what it proves:

- **A rule that accepts or rejects** (R1–R8, R13, `SHARE_PRECISION`): one case just inside the line and one just outside it. Weight 1 is accepted, 1.000001 is rejected.
- **A rule that computes** (R9–R12, R14): the case that tells this rule apart from the obvious alternative. Truncation is proven with a quotient that rounding would carry up; if both rules gave the same answer in every test, no test would prove which one the code follows.
- **An invariant** (INV1–INV7): it is checked by a test helper, and a helper that is wrong passes in silence. So each checker is also run against a plan broken on purpose to violate it, and must fail.

## Out of scope, for now

- **Whole shares only.** Brokers that cannot sell fractions need another rule for the target quantity, and there is no single right one (see [ADR 0001](adr/0001-truncate-to-share-precision.md)). It would come in as a second rule behind the same rebalance, with its own tests.
- **Fees and taxes.** Every trade is assumed free. With fees, the rebalance would have to pay for itself out of the portfolio value.
- **When to rebalance.** Periodic schedules or drift thresholds are a policy *over* this operation, not part of it.
- **Where prices come from.** The market is given. Fetching it is somebody else's job.
