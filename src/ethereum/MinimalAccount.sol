// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

import { IAccount } from "@account-abstraction/contracts/interfaces/IAccount.sol";
import { PackedUserOperation } from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { SIG_VALIDATION_FAILED, SIG_VALIDATION_SUCCESS } from "@account-abstraction/contracts/core/Helpers.sol";
import { IEntryPoint } from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";

/**
 * @title MinimalAccount
 * @author Esteban Pintos
 * @notice Basic account abstraction contract that can execute calls from an entry point.
 */
contract MinimalAccount is IAccount, Ownable {
    /// ERRORS
    error MinimalAccount__NotFromEntryPoint();
    error MinimalAccount__NotFromEntryPointOrOwner();
    error MinimalAccount__CallFailed(bytes result);

    /// STATE VARIABLES
    IEntryPoint private immutable i_entryPoint;

    /// MODIFIERS
    modifier requireFromEntryPoint() {
        if (msg.sender != address(i_entryPoint)) {
            revert MinimalAccount__NotFromEntryPoint();
        }
        _;
    }

    modifier requireFromEntryPointOrOwner() {
        if (msg.sender != address(i_entryPoint) && msg.sender != owner()) {
            revert MinimalAccount__NotFromEntryPointOrOwner();
        }
        _;
    }

    /// FUNCTIONS
    // CONSTRUCTOR
    constructor(address entryPoint) Ownable(msg.sender) {
        i_entryPoint = IEntryPoint(entryPoint);
    }

    // EXTERNAL FUNCTIONS

    // We need to be able to receive ether to pay for transactions
    receive() external payable { }

    /**
     * @notice Executes a call to a destination address with a value and function data
     * @notice Only the entry point or the owner can call this function
     * @param dest The destination address
     * @param value The value to send
     * @param functionData The function data to call
     */
    function execute(address dest, uint256 value, bytes calldata functionData) external requireFromEntryPointOrOwner {
        (bool success, bytes memory result) = dest.call{ value: value }(functionData);
        if (!success) {
            revert MinimalAccount__CallFailed(result);
        }
    }

    /**
     * @notice Function called by the entry point to validate the user operation
     * @dev Known issue: Nonce validation is done by the Entry point but it should be done here as well.
     * @param userOp The user operation
     * @param userOpHash The hash of the user operation
     * @param missingAccountFunds The missing account funds
     */
    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    )
        external
        requireFromEntryPoint
        returns (uint256 validationData)
    {
        validationData = _validateSignature(userOp, userOpHash);
        _payPrefund(missingAccountFunds);
    }

    // INTERNAL FUNCTIONS

    /**
     * @notice Validates that the signature of the user operation is the owner of the contract
     * @param userOp The user operation
     * @param userOpHash The hash of the user operation. EIP-191 version of the signed hash
     * @return validationData 0 if the signature is valid
     */
    function _validateSignature(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    )
        internal
        view
        returns (uint256 validationData)
    {
        // Converts to EIP-712 version of the signed hash so we can validate the signer with ECDSA
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(userOpHash);

        // Returns the address that signed the hash
        address signer = ECDSA.recover(ethSignedMessageHash, userOp.signature);

        if (signer != owner()) {
            return SIG_VALIDATION_FAILED;
        }

        return SIG_VALIDATION_SUCCESS;
    }

    /**
     * @notice Pays back the entry point
     * @param missingAccountFunds The missing account funds reported by the entry point
     */
    function _payPrefund(uint256 missingAccountFunds) internal {
        if (missingAccountFunds > 0) {
            (bool success,) = payable(msg.sender).call{ value: missingAccountFunds, gas: type(uint256).max }("");
            // Entry point should validate that the call was successful
            (success);
        }
    }

    // EXTERNAL VIEW FUNCTIONS
    /**
     * @notice Returns the entry point
     * @return The entry point
     */
    function getEntryPoint() external view returns (IEntryPoint) {
        return i_entryPoint;
    }
}
