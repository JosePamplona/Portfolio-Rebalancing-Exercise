# Target quantities are truncated to the share precision, and the rest stays as cash

A target value divided by a price rarely ends: 2,500 / 350 = 7.142857142… shares. A rebalance must still give tradeable quantities, and must not invent or lose money. We truncate every target quantity toward zero at the share precision (6 decimal places unless `SHARE_PRECISION` says otherwise), and whatever that leaves unspent stays in the portfolio as residual cash.

Truncating can only ever spend less than the portfolio value, never more, so cash never goes negative (`INV2`). The money is all accounted for: residual cash is exactly the portfolio value minus what the target quantities are worth (`INV1`). And it stays small: less than one smallest fraction of each allocated stock (`INV3`).

## Considered options

- **Round to nearest.** It gets each holding a little closer to its target, but rounding several of them up can spend more than there is. Cash could go negative by a few millionths, and it would take a correction pass to bring it back.
- **Exact fractions** (keeping 1/3 of a share as a rational number). Nothing would be lost, but no broker trades a third of a share. The precision is a fact of the market, not a choice of ours.
- **Whole shares.** This is the same rule at a precision of 0, but at that precision truncation leaves a lot of cash idle (up to one share of each stock). Doing better needs a second pass that spends the remainder, and there are several defensible ways to write it. It is left out of scope until it is asked for.

## Consequences

- The division has to be done so that the truncation is exact. A quotient rounded to some working precision and *then* truncated could land on the wrong side of a boundary: 1.9999999… shown as 2.000000.
- A portfolio is never balanced to the cent. It is balanced to one smallest fraction of a share per stock, and the tests assert exactly that bound, not a tolerance.
