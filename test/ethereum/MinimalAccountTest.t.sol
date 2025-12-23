// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MinimalAccount} from "src/ethereum/MinimalAccount.sol";
import {DeployMinimal} from "script/DeployMinimal.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";

contract MinimalAccountTest is Test {
    HelperConfig helperConfig;
    MinimalAccount minimalAccount;
    ERC20Mock usdc;

    address randomUser = makeAddr("randomUser");

    uint256 constant AMOUNT = 1e18;

    function setUp() public {
        DeployMinimal deployMinimal = new DeployMinimal();
        (helperConfig, minimalAccount) = deployMinimal.deployMinimalAccount();
        usdc = new ERC20Mock();
    }

    //USDC Mint
    //msg.sender -> MinimalAccount
    //MinimalAccount to approve some amount to the USDC contract
    //But must come from entrypoint
    //If success, means the alt-mempool nodes are able to bundle txn and submit
    //This tests - off chain signing to MinimialAccount -> call USDC (mint)
    //This test simulates the entire flow without the alt-mempool nodes
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
}
