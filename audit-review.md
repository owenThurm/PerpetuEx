

## Notes:

### H-01

H-01 points out a lack of consideration for the fees in the decreaseCollateral function, however the lacking consideration for fees is a larger issue when computing the leverage of a position to determine if it is liquidatable or not.

A position may be below the max leverage before subtracting the borrowing fees and therefore cannot be liquidatable by the definition of the _calculateUserLeverage function, but should still be liquidated as the borrowing fees make the position cross the maxLeverage threshold.



## Additional findings:


1. Critical

PnL is a storage variable that is updated when positions are decreased, therefore there are stepwise jumps in the value backing the liquidity provider tokens.

A malicious actor may sandwhich these stepwise jumps to extract value from the system.

2. Critical

The liquidate function fails to return any remaining collateral to the trader, therefore if the trader is only in a minor loss that makes them barely liquidatable they will still lose all of their collateral.


3. Medium

The getAverageOpenPrice function always rounds down the resulting average open price. For shorts a lower average open price is worse for the trader and better for the protocol, however for longs a lower average entry price is better for the trader and worse for the protocol.

The effect of this rounding will be minor, however it will err on the side of rewarding long traders at the expense of the protocol. To resist gameability and enforce profitiability for the LPs the protocol should always round in favor of the LPs, therefore rounding up the result of the average open price when the trade is long.

