# Prices live in the market, not in the portfolio

The exercise says the portfolio "has a collection of Stocks" and each stock has a current price. Read literally, the portfolio would store prices. We split the two instead: the portfolio holds tickers and quantities (what the investor owns), and a separate market, a set of stocks with their current prices, is handed to the rebalance (what it is worth right now).

What an investor owns changes when they trade, and what it is worth changes every second. Keeping them apart means a portfolio never carries a stale price, one portfolio can be rebalanced against several markets (yesterday's, today's, a simulated one), and a price that a holding and its allocation disagree about cannot exist. The `Stock` with `current_price/1` that the exercise asks for is still there: it is what the market is made of.
