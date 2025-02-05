// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

import { Script, console2 } from "forge-std/Script.sol";
import { EntryPoint } from "@account-abstraction/contracts/core/EntryPoint.sol";

contract HelperConfig is Script {
    error HelperConfig__InvalidChainId();

    struct NetworkConfig {
        address entryPoint;
        address account;
    }

    uint256 constant ETH_SEPOLIA_CHAIN_ID = 11_155_111;
    uint256 constant ZKSYNC_CHAIN_ID = 3000;
    uint256 constant LOCAL_CHAIN_ID = 31_337;
    address BURNER_WALLET = vm.envOr("BURNER_WALLET", address(1));
    address constant FOUNDRY_DEFAULT_WALLET = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;

    NetworkConfig public localNetworkConfig;
    mapping(uint256 chainId => NetworkConfig) public networkConfigs;

    constructor() {
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getEthSepoliaNetworkConfig();
        networkConfigs[ZKSYNC_CHAIN_ID] = getZkSyncSepoliaNetworkConfig();
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function getConfigByChainId(uint256 chainId) public returns (NetworkConfig memory) {
        if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilEthConfig();
        } else if (networkConfigs[chainId].account != address(0)) {
            return networkConfigs[chainId];
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    function getEthSepoliaNetworkConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({ entryPoint: 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789, account: BURNER_WALLET });
    }

    function getZkSyncSepoliaNetworkConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({ entryPoint: address(0), account: BURNER_WALLET });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (localNetworkConfig.account != address(0)) {
            return localNetworkConfig;
        }

        vm.startBroadcast(FOUNDRY_DEFAULT_WALLET);
        EntryPoint entryPoint = new EntryPoint();
        vm.stopBroadcast();
        return NetworkConfig({ entryPoint: address(entryPoint), account: FOUNDRY_DEFAULT_WALLET });
    }
}
