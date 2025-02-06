// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

import { Test, console2 } from "forge-std/Test.sol";
import { MinimalAccount } from "src/ethereum/MinimalAccount.sol";
import { HelperConfig } from "script/HelperConfig.s.sol";
import { DeployMinimalAccount } from "script/DeployMinimalAccount.s.sol";
import { ERC20Mock } from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import { SendPackedUserOp, PackedUserOperation, IEntryPoint, MessageHashUtils } from "script/SendPackedUserOp.s.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract MinimalAccountTest is Test {
    using MessageHashUtils for bytes32;

    MinimalAccount minimalAccount;
    HelperConfig helperConfig;
    HelperConfig.NetworkConfig networkConfig;
    ERC20Mock usdc;
    uint256 constant AMOUNT = 1e18;
    address RANDOM_USER = makeAddr("RANDOM_USER");
    SendPackedUserOp sendPackedUserOp;

    function setUp() public {
        DeployMinimalAccount deployMinimalAccount = new DeployMinimalAccount();
        (helperConfig, minimalAccount) = deployMinimalAccount.deployMinimalAccount();
        networkConfig = helperConfig.getConfig();
        usdc = ERC20Mock(networkConfig.usdc);
        sendPackedUserOp = new SendPackedUserOp();
    }
    // HelperFunctions

    function createUserOperation()
        internal
        view
        returns (PackedUserOperation memory packedUserOp, bytes32 userOperationHash)
    {
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address destination = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);

        // EntryPoint -> MinimalAccount (execute) -> USDC (mint)
        bytes memory executeCallData =
            abi.encodeWithSelector(MinimalAccount.execute.selector, destination, value, functionData);
        packedUserOp =
            sendPackedUserOp.generateSignedUserOperation(executeCallData, networkConfig, address(minimalAccount));

        // It doesn't hash the signature
        userOperationHash = IEntryPoint(networkConfig.entryPoint).getUserOpHash(packedUserOp);
    }

    // execute
    // Test we can mint USDC
    function testOwnerCanExecuteCommands() public {
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address destination = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);

        vm.prank(minimalAccount.owner());
        minimalAccount.execute(destination, value, functionData);

        assertEq(usdc.balanceOf(address(minimalAccount)), AMOUNT);
    }

    function testNonOwnerCannotExecuteCommands() public {
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address destination = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);

        vm.prank(RANDOM_USER);
        vm.expectRevert(MinimalAccount.MinimalAccount__NotFromEntryPointOrOwner.selector);
        minimalAccount.execute(destination, value, functionData);
    }

    function testRecoverSignedOp() public view {
        (PackedUserOperation memory packedUserOp, bytes32 userOperationHash) = createUserOperation();

        // Recovers the signer of the hashed PackedUserOperation
        address actualSigner = ECDSA.recover(userOperationHash.toEthSignedMessageHash(), packedUserOp.signature);

        assertEq(actualSigner, minimalAccount.owner());
    }

    // validateUserOp
    function testValidationOfUserOp() public {
        (PackedUserOperation memory packedUserOp, bytes32 userOperationHash) = createUserOperation();
        uint256 missingAccountFunds = 1e18;

        vm.prank(networkConfig.entryPoint);
        uint256 validationData = minimalAccount.validateUserOp(packedUserOp, userOperationHash, missingAccountFunds);
        assertEq(validationData, 0);
    }

    // Alt-Memepool Node -> EntryPoint (handleOps)-> MinimalAccount (execute) -> USDC (mint)
    function testEntryPointCanExecuteCommands() public {
        (PackedUserOperation memory packedUserOp,) = createUserOperation();

        vm.deal(address(minimalAccount), 1e18); // We need funds to pay back the memepool node
        console2.log(packedUserOp.sender);
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = packedUserOp;

        vm.prank(RANDOM_USER); // An Alt-Memepool Node
        IEntryPoint(networkConfig.entryPoint).handleOps(ops, payable(RANDOM_USER));

        assertEq(usdc.balanceOf(address(minimalAccount)), AMOUNT);
    }
}
