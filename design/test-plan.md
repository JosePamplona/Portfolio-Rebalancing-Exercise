# Test plan

Every test the suite will have, derived from [`domain-model.md`](domain-model.md) before any code. Each one names what it proves and comes as a pair (see *Testing* there): the case inside the line and the case outside it, or the case and the alternative it rules out. Every number below was computed beforehand with exact decimals.

Prices, quantities, cash and weights are written as decimals. `P` is the share precision; it is 6 unless a test says otherwise.

## Scenarios

The named portfolios the invariants run over (`test/support/scenarios.ex`). Several of them are also used by the tests below.

The allocation `25/25/50` is AAPL 0.25, MSFT 0.25, NVDA 0.50. *Day 1 prices* are AAPL 350, MSFT 525, NVDA 210; *day 2 prices* are AAPL 310, MSFT 505, NVDA 250.

| Id | Portfolio | Market | P | Trades expected | Cash after |
|---|---|---|---|---|---|
| **S1** from cash | cash 10,000, no holdings, 25/25/50 | day 1 | 6 | buy AAPL 7.142857, buy MSFT 4.761904, buy NVDA 23.809523 | 0.000620 |
| **S2** drifted | S1 after its trades | day 2 | 6 | sell NVDA 2.666666, buy AAPL 1.382488, buy MSFT 0.471476 | 0.000460 |
| **S3** already balanced | S2 after its trades | day 2 | 6 | none | 0.000460 |
| **S4** whole shares | cash 10,000, 25/25/50, rebalanced on day 1, then | day 2 | 0 | sell NVDA 2, buy AAPL 1, buy MSFT 1 | 305 |
| **S5** cents of a share | the same, at P 2 | day 2 | 2 | sell NVDA 2.66, buy AAPL 1.38, buy MSFT 0.47 | 3.85 |
| **S6** thirds | cash 1,000, X 0.333334, Y 0.333333, Z 0.333333 | X 7, Y 11, Z 13 | 6 | buy X 47.619142, buy Y 30.303000, buy Z 25.641000 | 0.000006 |
| **S7** held, not allocated | A 5, B 3, cash 0, allocation B 1 | A 20, B 10 | 6 | sell A 5, buy B 10 | 0 |
| **S8** allocated at weight 0 | A 2, cash 0, allocation A 0, B 1 | A 50, B 25 | 6 | sell A 2, buy B 4 | 0 |
| **S9** less than one share | cash 100, allocation A 1 | A 150 | 0 | none | 100 |
| **S10** empty | no holdings, no cash, allocation A 1 | A 10 | 6 | none | 0 |

S4 starts from day 1 at P 0 (buys AAPL 7, MSFT 4, NVDA 23, leaving 620), and S5 from day 1 at P 2 (AAPL 7.14, MSFT 4.76, NVDA 23.80, leaving 4.00). They cannot start from S2: its holdings have six decimals, which `R8` rejects at P 0 or 2.

## Building a portfolio: `portfolio_test.exs`

| Test | Proves | Inside the line | Outside the line |
|---|---|---|---|
| T1 | R1, E1 | weights A 1, B 0 are accepted | A 1.000001 → E1 for A; A −0.000001, B 1.000001 → E1 for A |
| T2 | R2, E2 | thirds 0.333334 + 0.333333 + 0.333333 are accepted | 0.333333 × 3 → E2 carrying 0.999999; 0.5 + 0.500001 → E2 carrying 1.000001 |
| T3 | R3, E3 | a holding of 0 is accepted | a holding of −0.000001 → E3 |
| T4 | R4, E4 | cash 0 is accepted | cash −0.000001 → E4 |
| T5 | error precedence | one rule broken → that error | R1 and R3 broken together → E1; weights out of range for B and A → E1 for A |

## Rebalancing: `rebalance_test.exs`

### Validation

| Test | Proves | Inside the line | Outside the line |
|---|---|---|---|
| T6 | R5, E5 | a market with an extra stock nobody holds or allocates is accepted, and the extra stock gets no trade | a held ticker missing from the market → E5; an allocated one → E5 |
| T7 | R6, E6 | price 0.000001 is accepted | price 0 → E6; price −1 → E6 |
| T8 | R7, E7 | each ticker once is accepted | the same ticker twice, even at the same price → E7 |
| T9 | R8, E8 | P 0 is accepted; a holding of 7.142857 at P 6 is accepted | P −1 → E8; P 2.5 → E8; a holding of 7.1428571 at P 6 → E8; S2's holdings at P 0 → E8 |

### Computation

| Test | Proves | The case | What it rules out |
|---|---|---|---|
| T10 | R9 | A 10, cash 100, allocation A 1, price 10 → buy A 10 | ignoring cash, which would give no trade |
| T11 | R10, truncation | S1: MSFT 2,500 / 525 = 4.7619047… → 4.761904 | rounding to nearest, which would give 4.761905 |
| T12 | R10, weight 0 | S7 and S8: a ticker not allocated, or allocated at 0, is sold whole | keeping it, or selling only part |
| T13 | R11, no zero trade | A 1, cash 0, price 10, allocation A 1 → no trades at all | a trade of quantity 0 in the list |
| T14 | R11, smallest trade | A 1, cash 0.00001, price 10, allocation A 1 → buy A 0.000001 | a difference of one smallest fraction being dropped |
| T15 | R12, order | S2 → sell NVDA, then buy AAPL, then buy MSFT | buys before sells, or trades in input order |
| T16 | worked example | S1 and S2, every trade with its exact quantity and amount, as in [`domain-model.md`](domain-model.md#worked-example) | any drift from the numbers computed by hand |

## Applying trades: `apply_trades_test.exs`

| Test | Proves | Inside the line | Outside the line |
|---|---|---|---|
| T17 | R13, E9 | selling exactly the whole holding is accepted | selling 0.000001 more than the holding → E9 |
| T18 | R13, E10 | a buy that spends exactly all the cash leaves cash 0 | a buy costing 0.000001 more than the cash → E10 |
| T19 | R13, order | S2's trades in their order are applied | the same trades with the buys first → E10, because the sells have not freed the cash yet |
| T20 | R14 | a holding sold whole is removed from the portfolio | a holding with quantity 0 left behind |

## Invariants: `invariants_test.exs`

Each invariant is checked on every scenario S1–S10. Then its checker is run against a plan broken on purpose, and must report the failure.

| Test | Proves | Holds on | The broken plan its checker must catch |
|---|---|---|---|
| T21 | INV1 conservation | S1–S10 | S2's plan with one trade's amount 0.000001 lower |
| T22 | INV2 cash never negative | S1–S10 | S2's plan with AAPL's buy 0.000002 larger (1.382490): it costs 0.000620 more than the 0.000460 left, so cash ends at −0.000160 |
| T23 | INV3 residual cash | S1–S10 | S2's plan without MSFT's buy, leaving 238.095840 in cash against a bound of 0.001065 |
| T24 | INV4 precision | S1–S10 | S2's plan with AAPL's buy as 1.3824881, seven decimals |
| T25 | INV5 idempotence | S1–S10 | a portfolio that was not rebalanced (S2 before its trades) passed off as rebalanced |
| T26 | INV6 input order | S1–S10, with holdings, allocation and market in reverse order | two different lists of trades passed off as equal |
| T27 | INV7 allocation reached | S1–S10 | S2's plan with NVDA's sell 0.000002 smaller (2.666664): NVDA ends 0.000470 over its target, past one fraction of 0.000250. One fraction smaller would stay inside it, 0.000220 over |

### Every scenario

| Test | Proves | The case | What it rules out |
|---|---|---|---|
| T29 | R9–R12 on every shape | each scenario S1–S10 gives exactly the trades and the cash after that its row names | a rule that holds on the worked example and breaks on whole shares, thirds, weight 0 or an empty portfolio |

## Configuration: `config_test.exs`

| Test | Proves | Inside the line | Outside the line |
|---|---|---|---|
| T28 | `SHARE_PRECISION` | unset → 6; `"0"` → 0; `"2"` → 2 | `""`, `"-1"`, `"2.5"`, `"abc"` → an error naming `SHARE_PRECISION` |

## Reading a rebalance: `report_test.exs`

The table of *Reading a rebalance* in the domain model. Each case compares the whole text, so a column out of place fails as surely as a wrong number.

| Test | Proves | The case | What it rules out |
|---|---|---|---|
| T30 | the table is the rebalance's computation | S2 gives the table of the domain model, row for row, with cash after 0.00046 | a market missing AAPL giving a table: it gives E5, as the rebalance does, and no text |
| T31 | money is shown exact | S1: cash 10000 and nothing held, its cash after 0.00062 shown as such | rounding money to cents, which would show the residual cash as 0.00 |
| T32 | the edges of the table | S7: A, held and not allocated, at weight 0.00 %, target 0, sell 5; S10: portfolio value 0, every actual weight `-` and no trade | a division by the portfolio value when it is 0; a ticker left out of the table because it has no weight |

## Coverage

| Line of the model | Tests |
|---|---|
| R1–R4, E1–E4 | T1–T5 |
| R5–R8, E5–E8 | T6–T9 |
| R9–R12 | T10–T16, T29 |
| R13–R14, E9–E10 | T17–T20 |
| INV1–INV7 | T21–T27 |
| Configuration | T28 |
| Reading a rebalance | T30–T32 |
