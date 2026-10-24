# Portfolio rebalancing

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

## How it was built

Domain first, then tests, then code: the documentation above came before any line of Elixir, and every test names the rule or invariant it proves.

An LLM (Claude) was used as a pair throughout, as the exercise allows. The conversations will be shared in [`design/llm-conversations/`](design/llm-conversations/).
