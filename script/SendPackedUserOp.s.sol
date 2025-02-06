// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

import { Script, console2 } from "forge-std/Script.sol";
import { PackedUserOperation } from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import { HelperConfig, CodeConstants } from "script/HelperConfig.s.sol";
import { IEntryPoint } from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract SendPackedUserOp is Script, CodeConstants {
    using MessageHashUtils for bytes32;

    function run() external { }

    function generateSignedUserOperation(
        bytes memory callData,
        HelperConfig.NetworkConfig memory config
    )
        public
        view
        returns (PackedUserOperation memory)
    {
        uint256 nonce = vm.getNonce(config.account);
        PackedUserOperation memory userOp = _generateUnsignedUserOperation(callData, config.account, nonce);

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
        uint128 maxPriorityFreePerGas = 256;
        uint128 maxFeePerGas = maxPriorityFreePerGas;

        return PackedUserOperation({
            sender: sender,
            nonce: nonce,
            initCode: hex"",
            callData: callData,
            accountGasLimits: bytes32(uint256(verificationGasLimit) << 128 | callGasLimit),
            preVerificationGas: verificationGasLimit,
            gasFees: bytes32(uint256(maxPriorityFreePerGas) << 128 | maxFeePerGas),
            paymasterAndData: hex"",
            signature: hex""
        });
    }
}
