# Mission 1 Review Notes


## Functionality Notes


### Liquidity Providers can deposit and withdraw liquidity

Great approach to inherit from ERC4626 and override the deposit/withdrawal related functions!

Some notes on this:

- You will want to override the `mint` function as well.
- In the redeem function the s_totalLiquidityDeposited should be updated after the assets is updated by the return value of super.redeem.


### A way to get the realtime price of the asset being traded.

I like the approach of putting this logic in a separate Oracle contract, and the convertPriceFromUsdToBtc function will prove useful!


### Traders can open a perpetual position for BTC, with a given size and collateral.

The PerpetuEx contract has a notion of Orders, I think these are better labelled as positions -- traditionally orders are pending "requests" to update a position's size or collateral.

E.g. I may have an increase order, that once executed increases the size of my position by $10,000. Or decreases the collateral of my position by 500 USDC.

We actually don't need to have this idea of orders since we will allow traders to create and update their positions in a single transaction. I think the idea of Orders in the PerpetuEx contract is a bit closer to what a Position would be. It has all of the details of the position, e.g. size, collateral, long vs. short, etc...


### Traders can increase the size of a perpetual position.

Great work! You even already have logic to prevent users from exceeding the max leverage, so you're ahead on Mission #2!



### Traders can increase the collateral of a perpetual position.

Great! The logic for this looks solid.



### Traders cannot utilize more than a configured percentage of the deposited liquidity.

It looks like this validation is implemented for the createOrder function, but not the increaseSize function -- therefore it may be possible for traders to surpass the open interest that should be supported by increasing the size of their position.



### Liquidity providers cannot withdraw liquidity that is reserved for positions.


I see you guys chose to override the maxWithdraw/maxRedeem functions, good thinking, I like this approach!




## Suggestions

- Consider renaming orders to positions in the codebase, The current Position struct could be replaced by a boolean field indicating long vs. short on what is now the Order struct. E.g. isLong.
- Be sure to override the mint function and use the assets determined by the super.redeem call.
- Be sure to validate the max utilization during the increaseSize function.
