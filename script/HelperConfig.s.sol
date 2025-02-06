// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

import { Script, console2 } from "forge-std/Script.sol";
import { EntryPoint } from "@account-abstraction/contracts/core/EntryPoint.sol";
import { ERC20Mock } from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract CodeConstants {
    uint256 constant ETH_SEPOLIA_CHAIN_ID = 11_155_111;
    uint256 constant ETH_ARBITRUM_SEPOLIA_CHAIN_ID = 421_614;
    uint256 constant ZKSYNC_CHAIN_ID = 3000;
    uint256 constant LOCAL_CHAIN_ID = 31_337;
    address constant ANVIL_DEFAULT_WALLET = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    uint256 constant ANVIL_DEFAULT_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
}

contract HelperConfig is Script, CodeConstants {
    error HelperConfig__InvalidChainId();

    struct NetworkConfig {
        address entryPoint;
        address account;
        // https://developers.circle.com/stablecoins/usdc-on-test-networks
        address usdc;
    }

    address BURNER_WALLET = vm.envOr("BURNER_WALLET", address(1));

    NetworkConfig public localNetworkConfig;
    mapping(uint256 chainId => NetworkConfig) public networkConfigs;

    constructor() {
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getEthSepoliaNetworkConfig();
        networkConfigs[ETH_ARBITRUM_SEPOLIA_CHAIN_ID] = getArbitrumSepoliaNetworkConfig();
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
        return NetworkConfig({
            entryPoint: 0x0000000071727De22E5E9d8BAf0edAc6f37da032,
            account: BURNER_WALLET,
            usdc: 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238
        });
    }

    function getArbitrumSepoliaNetworkConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            entryPoint: 0x0000000071727De22E5E9d8BAf0edAc6f37da032,
            account: BURNER_WALLET,
            usdc: 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d
        });
    }

    function getZkSyncSepoliaNetworkConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            entryPoint: address(0),
            account: BURNER_WALLET,
            usdc: 0xAe045DE5638162fa134807Cb558E15A3F5A7F853
        });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (localNetworkConfig.account != address(0)) {
            return localNetworkConfig;
        }

        vm.startBroadcast(ANVIL_DEFAULT_WALLET);
        EntryPoint entryPoint = new EntryPoint();
        ERC20Mock usdc = new ERC20Mock();

        vm.stopBroadcast();

        localNetworkConfig =
            NetworkConfig({ entryPoint: address(entryPoint), account: ANVIL_DEFAULT_WALLET, usdc: address(usdc) });

        return localNetworkConfig;
    }
}
