// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MinimalAccount} from "src/ethereum/MinimalAccount.sol";
import {DeployMinimal} from "script/DeployMinimal.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {SendPackedUserOps, PackedUserOperation, IEntryPoint} from "script/SendPackedUserOp.s.sol";
import {ECDSA} from "@openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";

contract MinimalAccountTest is Test {
    using MessageHashUtils for bytes32;

    HelperConfig helperConfig;
    MinimalAccount minimalAccount;
    ERC20Mock usdc;
    SendPackedUserOps sendPackedUserOp;

    address randomUser = makeAddr("randomUser");

    uint256 constant AMOUNT = 1e18;

    function setUp() public {
        DeployMinimal deployMinimal = new DeployMinimal();
        (helperConfig, minimalAccount) = deployMinimal.deployMinimalAccount();
        usdc = new ERC20Mock();
        sendPackedUserOp = new SendPackedUserOps();
    }

    //USDC Mint
    //msg.sender -> MinimalAccount
    //MinimalAccount to approve some amount to the USDC contract
    //But must come from entrypoint
    //If success, means the alt-mempool nodes are able to bundle txn and submit
    //This tests - off chain signing to MinimialAccount -> call USDC (mint)
    //This test simulates the entire flow without the alt-mempool nodes
    // * @notice Testing the flow of Off chain Sign -> Our AA address -> USDC Contract
    function testOwnerCanExecuteCommands() public {
        //Arrange
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT); //gets function selector of .mint from ERC20Mock.sol

        //Act
        vm.prank(minimalAccount.owner());
        minimalAccount.execute(dest, value, functionData); //value here is the ETH to send, the minting amount is found in the functionData

        //Assert
        assertEq(usdc.balanceOf(address(minimalAccount)), AMOUNT);
    }

    function testNonOwnerCannotExecuteCommands() public {
        //Arrange
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);

        //Act, Assert
        vm.expectRevert(MinimalAccount.MinimalAccount__NotFromEntryPointOrOwner.selector);
        vm.prank(randomUser);
        minimalAccount.execute(dest, value, functionData);
    }

    /**
     * @notice Testing the flow of Off chain Sign -> EntryPoint.sol -> Our AA address -> USDC Contract
     */
    function testRecoverSignedOp() public {
        //Arrange
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;

        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT); //Holds function call for USDC contract
        bytes memory executeCallData =
            abi.encodeWithSelector(MinimalAccount.execute.selector, dest, value, functionData); //Holds function call for our AA contract
        PackedUserOperation memory packedUserOps =
            sendPackedUserOp.generateSignedUserOperation(executeCallData, helperConfig.getConfig()); //Create the PackedUserOperation that EntryPoint.sol takes, PackedUserOperation holds the function calls for our AA contract and USDC contract
        bytes32 userOpHash = IEntryPoint(helperConfig.getConfig().entryPoint).getUserOpHash(packedUserOps); //Better to use account-abstraction getUserOpHash(), as if we hash ourselves, then we might do it differntly, as under the hood it hashes by encoding everything except the signature

        //Act
        address actualSigner = ECDSA.recover(userOpHash.toEthSignedMessageHash(), packedUserOps.signature); //.toEthSignedMessageHash() to ensure it is in ERC-191 format

        //Assert
        assertEq(actualSigner, minimalAccount.owner());
    }

    function testCreationfUserOps() public {}

    function testValidationOfUserOps() public {
        //1.Sign user ops
        //2.Call validation
        //3.Assert the return is correct

        //Arrange
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;

        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);
        bytes memory executeCallData =
            abi.encodeWithSelector(MinimalAccount.execute.selector, dest, value, functionData);
        PackedUserOperation memory packedUserOps =
            sendPackedUserOp.generateSignedUserOperation(executeCallData, helperConfig.getConfig());
        bytes32 userOpHash = IEntryPoint(helperConfig.getConfig().entryPoint).getUserOpHash(packedUserOps);
        uint256 missingAccountFunds = 1e18; //For validation test purpose, the value here does not matter

        //Act
        vm.prank(helperConfig.getConfig().entryPoint); //validateUserOp can only be called by entrypoint, so we prank as entrypoint
        uint256 validationData = minimalAccount.validateUserOp(packedUserOps, userOpHash, missingAccountFunds); //Internal function _validateSignature will return 0 for pass, 1 for fail

        //Assert
        assertEq(validationData, 0);
    }

    //function testEntryPointCanExecuteCommands() {}
}
