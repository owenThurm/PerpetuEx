// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {PerpetuEx} from "../../../src/PerpetuEx.sol";
import {PerpetuExTest} from "../../unit/PerpetuEx.t.sol";
import {console} from "forge-std/Test.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockV3Aggregator} from "../../mocks/MockV3Aggregator.sol";

contract MainNet is PerpetuExTest {
    /////////////////////
    /// Vault tests ///
    /////////////////////

    function canCallDepositWithoutAsset() public {
        vm.startPrank(LP);
        perpetuEx.deposit(0, LP);
        vm.stopPrank();
        assertEq(perpetuEx.totalAssets(), 0);
        assertEq(perpetuEx.balanceOf(LP), 0);
    }

    function testUseDeposit() public {
        vm.startPrank(LP);
        uint256 shares = perpetuEx.deposit(LIQUIDITY, LP);
        vm.stopPrank();
        assertEq(perpetuEx.totalAssets(), LIQUIDITY);
        assertEq(perpetuEx.totalSupply(), shares + DEAD_SHARES);
        assertEq(perpetuEx.balanceOf(LP), shares);
    }

    function testRemoveLiquidityWhileHavePositionOpen()
        public
        addLiquidity(LIQUIDITY)
        depositCollateralOpenLongPosition(COLLATERAL)
    {
        vm.startPrank(LP);
        vm.expectRevert();
        perpetuEx.withdraw(LIQUIDITY, LP, LP);
        perpetuEx.withdraw(1000e6, LP, LP);
        vm.stopPrank();
        assertEq(IERC20(usdc).balanceOf(LP), 1000e6);
    }
}
