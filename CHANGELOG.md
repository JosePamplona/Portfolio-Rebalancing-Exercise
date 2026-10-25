# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- The domain written down before any code: the glossary (`CONTEXT.md`), the
  domain model with its numbered rules, invariants and errors, a worked example
  computed with exact decimals, three ADRs, and the test plan derived from them
  (`design/`).
- `Portfolio.new/1`: builds a portfolio from holdings, cash and an allocation
  whose weights add up to exactly 1, or says which rule the input breaks.
- `Portfolio.rebalance/3`: the trades, sells first and then buys, that bring a
  portfolio back to its allocation at the market's current prices. Quantities
  are truncated to the share precision, and what truncation leaves stays as
  cash, so no cent and no fraction of a share is lost.
- `Portfolio.apply_trades/2`: the portfolio after a list of trades, applied one
  by one, refusing a sell larger than the holding or a buy larger than the cash.
- `Portfolio.Stock` with `current_price/1`, and `Portfolio.Trade`.
- `SHARE_PRECISION`: the number of decimal places a quantity may have, 6 by
  default, read once at boot; an invalid value stops the boot.
- The test suite: every rule tested on both sides of its line, and every
  invariant checked on ten scenarios by a checker that is itself tested against
  a plan broken on purpose.
- Credo and Dialyzer, a pre-commit hook running them with the formatter
  (`mix setup` turns it on), and CI running the same checks and the tests on
  every push to `main`.
- The README says what the repository answers, and walks through the worked
  example step by step in IEx.
