// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

import { BOOTLOADER_FORMAL_ADDRESS } from "@foundry-era-contracts/src/system-contracts/contracts/Constants.sol";
import {
    Transaction,
    MemoryTransactionHelper
} from "@foundry-era-contracts/src/system-contracts/contracts/libraries/MemoryTransactionHelper.sol";
import { ACCOUNT_VALIDATION_SUCCESS_MAGIC } from
    "@foundry-era-contracts/src/system-contracts/contracts/interfaces/IAccount.sol";
import { Test, console2 } from "forge-std/Test.sol";
import { ZkMinimalAccount } from "src/zksync/ZkMinimalAccount.sol";

import { ERC20Mock } from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract ZkMinimalAccountTest is Test {
    using MessageHashUtils for bytes32;

    ZkMinimalAccount minimalAccount;
    ERC20Mock usdc;
    uint256 constant AMOUNT = 1e18;
    uint8 constant TRANSACTION_TYPE = 113;
    bytes32 constant EMPTY_BYTES32 = bytes32(0);
    address USER;
    uint256 userPrivKey;

    function setUp() external {
        (USER, userPrivKey) = makeAddrAndKey("USER");
        minimalAccount = new ZkMinimalAccount();
        minimalAccount.transferOwnership(USER);
        usdc = new ERC20Mock();

        vm.deal(address(minimalAccount), AMOUNT);
    }

    /// Helper Functions
    function _createUnsignedTransaction(
        address from,
        uint8 transactionType,
        address to,
        uint256 value,
        bytes memory data
    )
        internal
        view
        returns (Transaction memory)
    {
        uint256 nonce = vm.getNonce(address(minimalAccount));
        bytes32[] memory factoryDeps = new bytes32[](0);
        return Transaction({
            txType: transactionType,
            from: uint256(uint160(from)),
            to: uint256(uint160(to)),
            gasLimit: 16_777_216,
            gasPerPubdataByteLimit: 16_777_216,
            maxFeePerGas: 16_777_216,
            maxPriorityFeePerGas: 16_777_216,
            paymaster: 0,
            nonce: nonce,
            value: value,
            reserved: [uint256(0), uint256(0), uint256(0), uint256(0)],
            data: data,
            signature: hex"",
            factoryDeps: factoryDeps,
            paymasterInput: hex"",
            reservedDynamic: hex""
        });
    }

    function _signTransaction(Transaction memory transaction) internal view returns (Transaction memory) {
        bytes32 unsignedTransactionHash = MemoryTransactionHelper.encodeHash(transaction);
        bytes32 digest = unsignedTransactionHash.toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivKey, digest);
        Transaction memory signedTransaction = transaction;
        signedTransaction.signature = abi.encodePacked(r, s, v);
        return signedTransaction;
    }

    // executeTransaction
    function testZkOwnerCanExecuteCommands() public {
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);

        Transaction memory transaction =
            _createUnsignedTransaction(minimalAccount.owner(), TRANSACTION_TYPE, dest, value, functionData);

        vm.prank(minimalAccount.owner());
        minimalAccount.executeTransaction(EMPTY_BYTES32, EMPTY_BYTES32, transaction);
        assertEq(usdc.balanceOf(address(minimalAccount)), AMOUNT);
    }

    // validateTransaction
    function testZkValidateTransaction() public {
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);

        Transaction memory transaction =
            _createUnsignedTransaction(minimalAccount.owner(), TRANSACTION_TYPE, dest, value, functionData);
        transaction = _signTransaction(transaction);

        vm.prank(BOOTLOADER_FORMAL_ADDRESS);
        bytes4 magic = minimalAccount.validateTransaction(EMPTY_BYTES32, EMPTY_BYTES32, transaction);
        assertEq(magic, ACCOUNT_VALIDATION_SUCCESS_MAGIC);
    }
}
