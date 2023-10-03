// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {DeployPerpetuEx} from "../../script/DeployPerpetuEx.sol";
import {PerpetuEx} from "../../src/PerpetuEx.sol";
import {Test, console} from "forge-std/Test.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPerpetuEx} from "../../src/IPerpetuEx.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

interface IUSDC {
    function balanceOf(address account) external view returns (uint256);

    function mint(address to, uint256 amount) external;

    function configureMinter(address minter, uint256 minterAllowedAmount) external;

    function masterMinter() external view returns (address);

    function approve(address spender, uint256 amount) external returns (bool);
}

contract PerpetuExTestAnvil is Test, IPerpetuEx {
    PerpetuEx public perpetuEx;
    HelperConfig public helperConfig;
    DeployPerpetuEx public deployer;
    address public priceFeed;
    address public constant USER = address(21312312312312312312);
    address public constant USER2 = address(456654456654456654546);
    address public constant LP = address(123123123123123123123);

    // USDC contract address on mainnet
    address usdcMock;
    // User mock params
    uint256 SIZE = 1;
    uint256 SIZE_2 = 2;
    uint256 COLLATERAL = 10000e6; // sufficient collateral to open a position with size 1
    uint256 DECREASE_COLLATERAL = 1500e6;
    // LP mock params
    uint256 LIQUIDITY = 1000000e6;

    uint256 private constant MAX_UTILIZATION_PERCENTAGE = 80; //80%
    uint256 private constant MAX_UTILIZATION_PERCENTAGE_DECIMALS = 100;
    uint256 private constant SECONDS_PER_YEAR = 31536000; // 365 * 24 * 60 * 60

    uint256 s_totalLiquidityDeposited;

    // Dead shares
    uint256 DEAD_SHARES = 1000;

    function setUp() external {
        deployer = new DeployPerpetuEx();
        (perpetuEx, helperConfig) = deployer.run();
        (priceFeed, usdcMock) = helperConfig.activeNetworkConfig();
        //ANVIL SETUP

        ERC20Mock(usdcMock).mint(USER, COLLATERAL * 1e12);
        ERC20Mock(usdcMock).mint(USER2, COLLATERAL * 1e12);
        ERC20Mock(usdcMock).mint(LP, LIQUIDITY * 1e12);

        vm.prank(USER);
        ERC20Mock(usdcMock).approve(address(perpetuEx), type(uint256).max);
        vm.prank(USER2);
        ERC20Mock(usdcMock).approve(address(perpetuEx), type(uint256).max);
        vm.prank(LP);
        ERC20Mock(usdcMock).approve(address(perpetuEx), type(uint256).max);
    }

    /// ====================================
    /// =========== Anvil Tests ============
    /// ====================================

    ////////////////////////
    // PnL & Borrowing Fees
    ////////////////////////

    // Needs it own setup
    // forge test --match-test "testUserPnlIncreaseIfBtcPriceIncrease" -vvvv
    function testUserPnlIncreaseIfBtcPriceIncrease() public {
        // setup
        MockV3Aggregator mockV3Aggregator = new MockV3Aggregator(8, 20000 * 1e8);
        PerpetuEx perpetuExBtcIncrease = new PerpetuEx(address(mockV3Aggregator), ERC20Mock(usdcMock));

        //     // Arrange - LP
        vm.prank(USER);
        ERC20Mock(usdcMock).approve(address(perpetuExBtcIncrease), type(uint256).max);

        vm.startPrank(LP);
        ERC20Mock(usdcMock).approve(address(perpetuExBtcIncrease), type(uint256).max);
        perpetuExBtcIncrease.deposit(LIQUIDITY * 1e12, LP);
        vm.stopPrank();

        // Arrange - USER
        vm.startPrank(USER);
        perpetuExBtcIncrease.depositCollateral(COLLATERAL * 1e12);
        perpetuExBtcIncrease.createPosition(SIZE, true);
        uint256 positionId = perpetuExBtcIncrease.userPositionIdByIndex(USER, 0);
        vm.stopPrank();

        //     //////////////// BTC price increases from $20_000 to $30_000 ////////////////
        int256 btcUsdcUpdatedPrice = 30000 * 1e8;
        mockV3Aggregator.updateAnswer(btcUsdcUpdatedPrice);
        uint256 currentPrice = perpetuExBtcIncrease.getPriceFeed(); // 30000 * 1e18

        // Get user's pnl
        int256 userIntPnl = perpetuExBtcIncrease.getUserPnl(USER);
        uint256 userPnl = uint256(userIntPnl);
        uint256 expectedPnl = SIZE * (currentPrice - (20000 * 1e18));
        assertEq(userPnl, expectedPnl);

        //     ////////////////////////////// One year after  //////////////////////////////
        uint256 currentTimestamp = block.timestamp;
        vm.warp(currentTimestamp + SECONDS_PER_YEAR);

        // Get borrowing fees after a year
        uint256 borrowingFees = perpetuExBtcIncrease.getBorrowingFees(USER);

        //     // Get user's pnl
        userIntPnl = perpetuExBtcIncrease.getUserPnl(USER);
        userPnl = uint256(userIntPnl) - borrowingFees;
        expectedPnl = SIZE * (currentPrice - (20000 * 1e18) - borrowingFees);
        assertEq(userPnl, expectedPnl);

        //     // Close position
        vm.startPrank(USER);
        console.log("borrowingFees", borrowingFees);
        perpetuExBtcIncrease.closePosition(positionId);
        vm.stopPrank();
        uint256 userBalanceAfterClosingPosition = IERC20(usdcMock).balanceOf(USER);
        console.log("userBalanceAfterClosingPosition", userBalanceAfterClosingPosition);
        uint256 expectedBalanceAfterClosingPosition = COLLATERAL * 1e12 + userPnl;
        assertEq(userBalanceAfterClosingPosition, expectedBalanceAfterClosingPosition);
    }
}
