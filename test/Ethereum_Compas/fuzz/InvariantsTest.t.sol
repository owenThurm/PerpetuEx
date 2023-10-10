// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DeployPerpetuEx} from "../../../script/DeployPerpetuEx.sol";
import {PerpetuEx} from "../../../src/PerpetuEx.sol";
import {Test, console} from "forge-std/Test.sol";
import {HelperConfig} from "../../../script/HelperConfig.s.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPerpetuEx} from "../../../src/IPerpetuEx.sol";
import {MockV3Aggregator} from "../../mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

interface IUSDC {
    function balanceOf(address account) external view returns (uint256);

    function mint(address to, uint256 amount) external;

    function configureMinter(address minter, uint256 minterAllowedAmount) external;

    function masterMinter() external view returns (address);

    function approve(address spender, uint256 amount) external returns (bool);
}

contract InvariantsTest is StdInvariant, Test {
    PerpetuEx public perpetuEx;
    HelperConfig public helperConfig;
    DeployPerpetuEx public deployer;
    address public priceFeed;
    address public constant USER = address(21312312312312312312);
    address public constant USER2 = address(456654456654456654546);
    address public constant LP = address(123123123123123123123);

    // USDC contract address on mainnet
    address usdc;
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
    uint256 private constant BORROWING_RATE = 10;
    uint256 private constant DECIMALS_DELTA = 1e12; // btc decimals - usdc decimals
    uint256 private constant DECIMALS_PRECISION = 1e4;

    uint256 s_totalLiquidityDeposited;

    // Dead shares
    uint256 DEAD_SHARES = 1000;

    function setUp() external {
        deployer = new DeployPerpetuEx();
        (perpetuEx, helperConfig) = deployer.run();
        (priceFeed, usdc) = helperConfig.activeNetworkConfig();

        // MAINNET SETUP
        // spoof .configureMinter() call with the master minter account
        vm.prank(IUSDC(usdc).masterMinter());
        // allow this test contract to mint USDC
        IUSDC(usdc).configureMinter(address(this), type(uint256).max);
        // mint max to the test contract (or an external user)
        IUSDC(usdc).mint(USER, COLLATERAL);
        IUSDC(usdc).mint(USER2, COLLATERAL);
        // mint max to the LP account
        IUSDC(usdc).mint(LP, LIQUIDITY);
        deployer = new DeployPerpetuEx();
        (perpetuEx, helperConfig) = deployer.run();
        (priceFeed,) = helperConfig.activeNetworkConfig();

        vm.prank(USER);
        IERC20(usdc).approve(address(perpetuEx), type(uint256).max);
        vm.prank(LP);
        IERC20(usdc).approve(address(perpetuEx), type(uint256).max);
        vm.prank(USER2);
        IERC20(usdc).approve(address(perpetuEx), type(uint256).max);
    }
}
