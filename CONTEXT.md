# Portfolio Management

The part of a personal investments app that knows what an investor owns, what they aim to own, and which trades bring the first back to the second.

## Language

### What is owned

**Portfolio**:
Everything one investor owns in this module: their holdings, their cash, and the allocation they aim for.
_Avoid_: Account, fund, wallet

**Holding**:
A quantity of one stock owned by a portfolio. It is a number of shares, never an amount of money.
_Avoid_: Position, asset, stock (for the quantity)

**Cash**:
Money in the portfolio that is not invested in any stock.
_Avoid_: Balance, funds, buying power

**Quantity**:
A number of shares, possibly fractional, held or traded.
_Avoid_: Units, amount (amount is money)

### What the market says

**Stock**:
A company's share as the market lists it, named by its ticker and carrying its current price.
_Avoid_: Security, equity, asset

**Ticker**:
The short code that names a stock, such as `AAPL` or `META`.
_Avoid_: Symbol, code

**Current price**:
The last available price of one share of a stock.
_Avoid_: Quote, rate, value (value is quantity × price)

**Market**:
The set of stocks, with their current prices, that a rebalance is computed against.
_Avoid_: Prices, quotes, feed

### What is aimed for

**Allocation**:
The distribution of the portfolio's value that the investor aims for, as a weight per ticker.
_Avoid_: Plan, target portfolio, distribution, strategy

**Weight**:
The fraction of the portfolio's value an allocation assigns to one ticker, between 0 and 1. A portfolio's weights add up to exactly 1.
_Avoid_: Percentage, share (share is a unit of stock), ratio

### Measuring

**Market value**:
What a holding is worth now: its quantity times its stock's current price.
_Avoid_: Value (alone), worth, balance

**Portfolio value**:
The cash plus the market value of every holding.
_Avoid_: Total, net worth, AUM

**Drift**:
How far a holding's actual weight in the portfolio value has moved from its allocated weight, because prices moved and quantities did not.
_Avoid_: Deviation, imbalance, skew

### Rebalancing

**Rebalance**:
Computing the trades that bring every holding to its allocated weight of the current portfolio value.
_Avoid_: Adjust, reallocate, sync

**Target quantity**:
The quantity of a stock a holding should have after a rebalance.
_Avoid_: Goal, desired quantity

**Trade**:
One instruction to buy or sell a quantity of one stock at its current price.
_Avoid_: Order, transaction, operation

**Share precision**:
The number of decimal places a quantity may have; the smallest tradeable fraction of a share is 10⁻ᴺ.
_Avoid_: Lot size, decimals, scale

**Residual cash**:
The cash left after a rebalance because target quantities are truncated to the share precision. It is always less than one smallest fraction of each allocated stock.
_Avoid_: Dust, leftover, rounding error
