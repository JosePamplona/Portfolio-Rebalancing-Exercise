# Portfolio rebalancing

A portfolio holds some stocks and some cash, and aims for an allocation: say 25 % AAPL, 25 % MSFT, 50 % NVDA. Prices move, quantities do not, and the real weights drift away from the allocation. This module computes the trades that bring the portfolio back to it, without inventing or losing a cent or a fraction of a share.

> **Status: design.** The domain is written down. The tests, and then the code, are derived from it next.

## Reading order

1. [`CONTEXT.md`](CONTEXT.md): the domain's language. One word per concept, and the synonyms it rules out.
2. [`docs/domain-model.md`](docs/domain-model.md): the building blocks, the numbered rules and invariants every test cites, a worked example with exact numbers, and the planned structure.
3. [`docs/adr/`](docs/adr/): the decisions a reader could wonder about.
   - [0001](docs/adr/0001-truncate-to-share-precision.md): quantities are truncated to the share precision, and the rest stays as cash.
   - [0002](docs/adr/0002-prices-live-in-the-market.md): prices live in the market, not in the portfolio.
   - [0003](docs/adr/0003-a-library-not-an-application.md): a library, not an application.

## How it was built

Domain first, then tests, then code: the documentation above came before any line of Elixir, and every test names the rule or invariant it proves.

An LLM (Claude) was used as a pair throughout, as the exercise allows. The conversations will be shared in [`docs/llm-conversations/`](docs/llm-conversations/).
