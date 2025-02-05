// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

import { Script, console2 } from "forge-std/Script.sol";
import { MinimalAccount } from "src/ethereum/MinimalAccount.sol";
import { HelperConfig } from "script/HelperConfig.s.sol";

contract DeployMinimalAccount is Script {
    function run() external { }

    function deployMinimalAccount() public returns (HelperConfig helperConfig, MinimalAccount minimalAccount) {
        helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        vm.startBroadcast(config.account);
        minimalAccount = new MinimalAccount(config.entryPoint);
        minimalAccount.transferOwnership(msg.sender);
        vm.stopBroadcast();
    }
}
