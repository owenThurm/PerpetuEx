// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {PerpetuEx} from "../src/PerpetuEx.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {console} from "forge-std/Test.sol";

contract DeployPerpetuEx is Script {
    function run() external returns (PerpetuEx, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        (address priceFeed, address usdc) = helperConfig.activeNetworkConfig();
        console.log("Price feed address: %s", priceFeed);
        console.log("USDC address: %s", (usdc));
        vm.startBroadcast();
        PerpetuEx perpetuex = new PerpetuEx(priceFeed, IERC20(usdc));
        vm.stopBroadcast();
        return (perpetuex, helperConfig);
    }
}
