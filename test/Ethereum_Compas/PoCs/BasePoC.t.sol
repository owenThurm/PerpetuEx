// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {PerpetuEx} from "../../../src/PerpetuEx.sol";
import {Anvil} from "../unit/Anvil.t.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {console} from "forge-std/Test.sol";

contract BasePoC is Anvil {
    ////////////////////////
    // Modifiers
    ////////////////////////
    modifier depositLiquidity() {
        vm.startPrank(LP);
        ERC20Mock(usdcMock).approve(address(perpetuEx), type(uint256).max);
        perpetuEx.deposit(LIQUIDITY * 1e12, LP);
        vm.stopPrank();
        _;
    }

    modifier openPosition() {
        vm.startPrank(USER);
        perpetuEx.depositCollateral(COLLATERAL * 1e12);
        perpetuEx.createPosition(SIZE, true);
        vm.stopPrank();
        _;
    }

    function testBasePoC() public {
        super.testUserPnlIncreaseIfBtcPriceIncrease();
    }
}
