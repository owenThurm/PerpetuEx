// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {PerpetuEx} from "../../../src/PerpetuEx.sol";
import {PerpetuExTestAnvil} from "../../unit/PerpetuExAnvil.t.sol";
import {console} from "forge-std/Test.sol";

import {MockV3Aggregator} from "../../mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Anvil is PerpetuExTestAnvil {
    modifier addLiquidity(uint256 amount) {
        vm.startPrank(LP);
        ERC20Mock(usdcMock).approve(address(perpetuEx), type(uint256).max);
        perpetuEx.deposit(amount, LP);
        vm.stopPrank();
        _;
    }

    modifier depositCollateralOpenLongPosition(uint256 amount) {
        vm.startPrank(USER);
        perpetuEx.depositCollateral(amount);
        perpetuEx.createPosition(SIZE, true);
        vm.stopPrank();
        _;
    }

    /////////////////////
    /// Vault tests ///
    /////////////////////

    function testUseDeposit() public {
        vm.startPrank(LP);
        uint256 shares = perpetuEx.deposit(LIQUIDITY, LP);
        vm.stopPrank();
        assertEq(perpetuEx.totalAssets(), LIQUIDITY);
        assertEq(perpetuEx.totalSupply(), shares + DEAD_SHARES);
        assertEq(perpetuEx.balanceOf(LP), shares);
    }

    function testRemoveLiquidityWhilePnLisNegative()
        public
        addLiquidity(LIQUIDITY * 1e12)
        depositCollateralOpenLongPosition(COLLATERAL * 1e12)
    {
        MockV3Aggregator(priceFeed).updateAnswer(3000e8);
        vm.startPrank(LP);
        vm.expectRevert();
        perpetuEx.withdraw(LIQUIDITY * 1e12, LP, LP);
        perpetuEx.withdraw(50000e12, LP, LP);
        vm.stopPrank();
        assertEq(ERC20Mock(usdcMock).balanceOf(LP), 50000e12);
    }

    function testRemoveLiquidityWhilePnLisPostive()
        public
        addLiquidity(LIQUIDITY * 1e12)
        depositCollateralOpenLongPosition(COLLATERAL * 1e12)
    {
        MockV3Aggregator(priceFeed).updateAnswer(800e8);
        vm.startPrank(LP);
        vm.expectRevert();
        perpetuEx.withdraw(LIQUIDITY * 1e12, LP, LP);
        perpetuEx.withdraw(50000e12, LP, LP);
        vm.stopPrank();
        assertEq(ERC20Mock(usdcMock).balanceOf(LP), 50000e12);
    }
}
