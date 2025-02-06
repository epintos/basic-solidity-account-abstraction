// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

import { Script, console2 } from "forge-std/Script.sol";
import { PackedUserOperation } from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import { HelperConfig, CodeConstants } from "script/HelperConfig.s.sol";
import { IEntryPoint } from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { DevOpsTools } from "lib/foundry-devops/src/DevOpsTools.sol";
import { MinimalAccount } from "src/ethereum/MinimalAccount.sol";

contract SendPackedUserOp is Script, CodeConstants {
    using MessageHashUtils for bytes32;

    function run() external {
        HelperConfig helperConfig = new HelperConfig();
        address dest = helperConfig.getConfig().usdc;
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(IERC20.approve.selector, msg.sender, 1e18);
        bytes memory executeCallData =
            abi.encodeWithSelector(MinimalAccount.execute.selector, dest, value, functionData);

        address minimalAccountAddress = DevOpsTools.get_most_recent_deployment("MinimalAccount", block.chainid);
        PackedUserOperation memory userOp =
            generateSignedUserOperation(executeCallData, helperConfig.getConfig(), minimalAccountAddress);

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = userOp;

        vm.startBroadcast();
        IEntryPoint(helperConfig.getConfig().entryPoint).handleOps(ops, payable(helperConfig.getConfig().account));
        vm.stopBroadcast();
    }

    function generateSignedUserOperation(
        bytes memory callData,
        HelperConfig.NetworkConfig memory config,
        address minimalAccount
    )
        public
        view
        returns (PackedUserOperation memory)
    {
        uint256 nonce = vm.getNonce(minimalAccount) - 1;
        PackedUserOperation memory userOp = _generateUnsignedUserOperation(callData, minimalAccount, nonce);

        bytes32 userOpHash = IEntryPoint(config.entryPoint).getUserOpHash(userOp);
        bytes32 digest = userOpHash.toEthSignedMessageHash();

        uint8 v;
        bytes32 r;
        bytes32 s;

        if (block.chainid == LOCAL_CHAIN_ID) {
            (v, r, s) = vm.sign(ANVIL_DEFAULT_KEY, digest);
        } else {
            (v, r, s) = vm.sign(config.account, digest);
        }

        userOp.signature = abi.encodePacked(r, s, v); // Order is important
        return userOp;
    }

    function _generateUnsignedUserOperation(
        bytes memory callData,
        address sender,
        uint256 nonce
    )
        internal
        pure
        returns (PackedUserOperation memory)
    {
        uint128 verificationGasLimit = 16_777_216;
        uint128 callGasLimit = verificationGasLimit;
        uint128 maxPriorityFeePerGas = 256;
        uint128 maxFeePerGas = maxPriorityFeePerGas;

        return PackedUserOperation({
            sender: sender,
            nonce: nonce,
            initCode: hex"",
            callData: callData,
            accountGasLimits: bytes32(uint256(verificationGasLimit) << 128 | callGasLimit),
            preVerificationGas: verificationGasLimit,
            gasFees: bytes32(uint256(maxPriorityFeePerGas) << 128 | maxFeePerGas),
            paymasterAndData: hex"",
            signature: hex""
        });
    }
}
