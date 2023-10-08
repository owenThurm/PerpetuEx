// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {PerpetuEx} from "../../../src/PerpetuEx.sol";
import {PerpetuExTest} from "../../unit/PerpetuEx.t.sol";
import {IUSDC} from "../../unit/PerpetuEx.t.sol";

contract MainNet is PerpetuExTest {
    uint256 ADDITIONAL_COLLATERAL = 5000e6;

    modifier increaseUserAllowance(address user, uint256 amount) {
        vm.prank(IUSDC(usdc).masterMinter());
        IUSDC(usdc).configureMinter(address(this), type(uint256).max);
        IUSDC(usdc).mint(user, amount);
        vm.prank(user);
        IERC20(usdc).approve(address(perpetuEx), amount);
        _;
    }

    /////////////////////
    /// Create Position
    /////////////////////
    function testCreatePositionAfterPositionExists()
        public
        addLiquidity(LIQUIDITY)
        addCollateral(COLLATERAL)
    {
        vm.startPrank(USER);
        perpetuEx.createPosition(SIZE, true);
        vm.expectRevert(PerpetuEx__OpenPositionExists.selector);
        perpetuEx.createPosition(SIZE, true);
        vm.stopPrank();
    }

    function testCreatePositionWithNoSize()
        public
        addLiquidity(LIQUIDITY)
        addCollateral(COLLATERAL)
    {
        vm.prank(USER);
        vm.expectRevert(PerpetuEx__InvalidSize.selector);
        perpetuEx.createPosition(0, true);
    }

    /////////////////////
    /// Increase Position
    /////////////////////
    function testIncreaseSizeWithInvalidSize()
        public
        addLiquidity(LIQUIDITY)
        depositCollateralOpenLongPosition(COLLATERAL)
    {
        vm.startPrank(USER);
        uint256 positionId = perpetuEx.userPositionIdByIndex(USER, 0);
        vm.expectRevert(PerpetuEx__InvalidSize.selector);
        perpetuEx.increaseSize(positionId, 0);
    }

    /////////////////////
    /// Decrease Size
    /////////////////////

    function testDecreaseSizeWithNoSize()
        public
        longPositionOpened(LIQUIDITY, COLLATERAL, SIZE_2)
    {
        vm.startPrank(USER);
        uint256 positionId = perpetuEx.userPositionIdByIndex(USER, 0);
        vm.expectRevert(PerpetuEx__InvalidSize.selector);
        perpetuEx.decreaseSize(positionId, 0);
    }

    /////////////////////
    /// Decrease Collateral
    /////////////////////

    function testDecreaseCollateralWithInsufficientCollateral()
        public
        longPositionOpened(LIQUIDITY, COLLATERAL, SIZE)
    {
        vm.startPrank(USER);
        vm.expectRevert(PerpetuEx__InsufficientCollateral.selector);
        perpetuEx.decreaseCollateral(COLLATERAL + 1);
    }

    function testDecreaseCollateralWithZeroAmount()
        public
        longPositionOpened(LIQUIDITY, COLLATERAL, SIZE)
    {
        vm.startPrank(USER);
        vm.expectRevert(PerpetuEx__InvalidAmount.selector);
        perpetuEx.decreaseCollateral(0);
    }

    function testDecreaseCollateralFailForLeverage()
        public
        longPositionOpened(LIQUIDITY, COLLATERAL, SIZE)
    {
        uint256 MAX_LEVERAGE = 0;
        vm.prank(perpetuEx.owner());
        perpetuEx.setMaxLeverage(MAX_LEVERAGE);
        vm.startPrank(USER);
        vm.expectRevert(PerpetuEx__InvalidAmount.selector);
        perpetuEx.decreaseCollateral(DECREASE_COLLATERAL);
    }

    /////////////////////
    /// Increase Collateral
    /////////////////////

    function testIncreaseCollateralWithInvalidCollateral()
        public
        longPositionOpened(LIQUIDITY, COLLATERAL, SIZE)
    {
        vm.prank(USER);
        vm.expectRevert(PerpetuEx__InvalidCollateral.selector);
        perpetuEx.increaseCollateral(0, 0);
    }

    function testIncreaseCollateral1()
        public
        longPositionOpened(LIQUIDITY, COLLATERAL, SIZE)
        increaseUserAllowance(USER, ADDITIONAL_COLLATERAL)
    {
        vm.startPrank(USER);
        uint256 positionId = perpetuEx.userPositionIdByIndex(USER, 0);

        perpetuEx.increaseCollateral(positionId, ADDITIONAL_COLLATERAL);
        (, , , uint256 collateral, , ) = perpetuEx.positions(positionId);
        assertEq(collateral, ADDITIONAL_COLLATERAL + COLLATERAL);
        vm.stopPrank();
    }
}
