# PerpetuEx Perpetual Future Protocol

## The [`PerpetuEx`](src/PerpetuEx.sol) Contract

### Introduction

The PerpetuEx smart contract is a Perpetual Futures protocol built on the Ethereum blockchain. It provides a platform for users to create and manage leveraged trading orders, enabling both long and short positions in wrapped Bitcoin (WBTC)

### Contract Overview

The PerpetuEx contract is a complex financial instrument with several features and components. Here's a brief overview of its key components:

- Positions: Users can create trading positions (long or short) with specified sizes . These positions are tracked and managed by the contract.
  The user does not hold the underlying asset; they are simply speculating on the price of the underlying asset.

- Collateral: Users can deposit collateral in the form of a stablecoin (USDC) to support their trading positions.
  Collateral allows determining the user's leverage of a given position.

  For example, if a user deposits $300 as collateral and create a long position with size of 1 on WBTC, given a WBTC price of $30,000, their leverage is x10.

  The maximum allowed leverage is 20x. If the user's position exceeds this level due to a market move in the opposite direction of their anticipation, the order is subject to liquidation. In case of liquidation, the sudden loss will be reduced by the collateral, which can be withdrawn if desired.

- Liquidity Management: The contract enforces liquidity reserve restrictions to ensure the safety of funds. It calculates and updates open interest positions based on user orders.

  Liquidity is provided by liquidity providers (LPs). These LPs receive a share proportional to their liquidity deposit. When withdrawing liquidity, the LP must return their shares to the contract, which will be burned, in order to receive the corresponding amount in USDC.

  The liquidity for depositing/withdrawing tokens and share minting/burning are managed following EIP-4626 for vault tokens.

- PnL Calculation: The contract calculates profit and loss (PnL) for each user based on the price movements of the underlying asset.

### Parameters

The PerpetuEx contract has several configurable parameters that control its behavior. Here are the key parameters:

- `priceFeed`: Address of the price feed contract used for asset pricing.

- `usdc`: Address of the USDC stablecoin contract.

- `maxUtilizationPercentage`: Maximum utilization percentage for liquidity.

- `borrowingRate`: The rate for accumulated borrowing fees over time for open positions

- `liquidationDenominator`: The denominator determines how much of the liquidated collateral are given as a reward to the liquidator

- `maxLeverage`: Maximum leverage allowed for trading.

- `s_totalLiquidityDeposited`: Total liquidity deposited by LPs

- `s_totalPnl`: Total PnL of users

- `s_shortOpenInterest`: Total amount (size \* price) of short orders opened in the protocol

- `s_longOpenInterestInTokens`: Total size (number of wBTC tokens) of long opened in the protocol

### Deposit

Traders and liquidity providers must first make a deposit in USDC

- `depositCollateral(uint256 _amount)`: Traders deposit the desired amount in USDC, and this deposit serves as collateral to enter the market.

- `deposit(uint256 assets, address receiver)`: Liquidity providers deposit their desired amount of USDC and, in return, receive a number of shares proportionate to their amount relative to the total liquidity provided by all LPs. This way, LPs directly act as counterparties to the traders.

### Withdraw

- `withdrawCollateral()`: Traders can withdraw their collateral as long as they do not have an open position in the market.

- `withdraw(uint256 assets, address receiver, address owner)`: Liquidity Providers can withdraw their desired amount of liquidity as long as the withdrawal does not impact the ability to pay out profits to traders

### Fees

Fees are an important component of DeFi protocols. PerpetuEx has two types of fees:
`liquidatorFee` and `borrowingFee`.

Liquidation fees incentivize liquidators to liquidate the positions of users whose leverage exceeds the `maxLeverage``.

`liquidatorFee` is a percentage of the position’s remaining collateral

As a result, liquidators have a strong incentive to close positions as soon as the `maxLeverage` is exceeded to minimize the risk of the collateral diminishing further if the BTC price movement continues.
A decrease in the user's collateral due to additional losses would result in a lower amount received by the liquidators.

It's crucial for liquidation to occur as quickly as possible when `maxLeverage` is reached, so that users' losses don't deepen due to a delay in liquidation.

On the other hand, swift liquidation prevents a position that has exceeded `maxLeverage` from becoming healthy again due to a market reversal.

For example, if Bob holds a SHORT position on BTC, and the price of BTC increases significantly, causing his LEVERAGE to exceed the `maxLeverage`, If his position is not liquidated quickly, two undesirable scenarios are likely:

1. The price of BTC decreases in a correction, allowing Bob's leverage to fall below the `maxLeverage` threshold.
   In this case, Bob could close his position and reduce his losses when he should have been liquidated.
   The difference in losses he endured should have gone to the liquidity providers as a profit, who are the first to be impacted in this scenario.

2. The price of BTC continues to rise, further deepening Bob's losses. The difference in losses becomes a gain for the liquidity providers, but Bob incurs even greater losses in this case and the liquidator will receive a lower amount.

### Conclusion

The PerpetuEx smart contract is a powerful DeFi tool for leveraged trading and managing trading positions. Users can deposit collateral, create orders, and benefit from price movements while adhering to strict liquidity management rules.

For more details on using the contract and its functions, please refer to the contract's source code and comments.

**Disclaimer:** This README serves as a high-level overview of the PerpetuEx contract. Users should review the contract source code and seek professional advice before interacting with it. The contract involves financial risk, and all trading decisions are the responsibility of the user.

# Getting Started

## Requirements

- [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
  - You'll know you did it right if you can run `git --version` and you see a response like `git version x.x.x`
- [foundry](https://getfoundry.sh/)
  - You'll know you did it right if you can run `forge --version` and you see a response like `forge 0.2.0 (816e00b 2023-03-16T00:05:26.396218Z)`

### Environment
Copy the `.env.local` file and rename it to `.env`. Set your `MAINNET_RPC_URL` in order to start testing 

## Testing
### Test on Mainnet
```
make test-mainnet
```

### Test on Anvil
```
make test-anvil
```

### Test Coverage
```
make coverage-mainnet
```