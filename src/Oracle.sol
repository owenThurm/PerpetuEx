// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

library Oracle {
    uint256 private constant DECIMALS_ADJUSTMENT = 1e10; // To adjust the 8 decimal BTC price to 18 decimals
    uint256 private constant PRECISION = 1e18; // Represents 18 decimals, commonly used in Ethereum

    function getBtcInUsdPrice(AggregatorV3Interface priceFeed) public view returns (uint256) {
        (, int256 answer,,,) = priceFeed.latestRoundData();
        // BTC/USD rate in 18 digit to avoid truncation errors
        return uint256(answer) * DECIMALS_ADJUSTMENT;
    }

    function convertPriceFromUsdToBtc(uint256 amountInUsd, AggregatorV3Interface priceFeed)
        public
        view
        returns (uint256)
    {
        uint256 btcInUsd = getBtcInUsdPrice(priceFeed);
        // BTC/USD rate in 18 digits to avoid truncation errors
        return (amountInUsd * btcInUsd) / PRECISION;
    }
}
