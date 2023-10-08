// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {PerpetuEx} from "../../../src/PerpetuEx.sol";
import {BasePoC} from "./BasePoC.t.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

import {console} from "forge-std/Test.sol";

contract DecreaseCollateralIgnoresFees is BasePoC {
    function testDecreaseCollateralIgnoresFess()
        public
        depositLiquidity
        openPosition
    {
        console.log(perpetuEx.getLeverage(USER));
        //TODO: WORK IN PROGRESS
    }
}
