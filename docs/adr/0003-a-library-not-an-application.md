# A library, not an application

The answer is a plain Elixir library (`mix new`), with no Phoenix, no database and no web layer. The exercise asks for a class and one method, and whoever reads the repository should reach the rebalance in seconds, not after an endpoint, a router and a schema.

The domain depends on nothing but exact decimals, so a demonstration (a LiveView replaying price histories, say) can be added later as a separate layer that calls it, without touching it. Whether that demonstration is worth adding is decided once the domain and its tests are done.
