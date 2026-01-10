// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "lib/forge-std/src/Test.sol";
import {ZkMinimalAccount} from "src/zksync/ZkMinimalAccount.sol";
import {ERC20Mock} from "lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";

import {Utils} from "lib/foundry-era-contracts/src/system-contracts/contracts/libraries/Utils.sol";

// zkSync Era Imports
import {
    Transaction,
    MemoryTransactionHelper
} from "lib/foundry-era-contracts/src/system-contracts/contracts/libraries/MemoryTransactionHelper.sol";
import {BOOTLOADER_FORMAL_ADDRESS} from "lib/foundry-era-contracts/src/system-contracts/contracts/Constants.sol";
import {
    ACCOUNT_VALIDATION_SUCCESS_MAGIC
} from "lib/foundry-era-contracts/src/system-contracts/contracts/interfaces/IAccount.sol";

//OZ Imports
import {MessageHashUtils} from "lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";

contract ZkMinimalAccountTest is Test {
    using MessageHashUtils for bytes32;

    ZkMinimalAccount minimalAccount;
    ERC20Mock usdc;

    uint256 constant AMOUNT = 1e18;
    bytes32 constant EMPTY_BYTES32 = bytes32(0);
    address public Alice = makeAddr("Alice");
    address constant ANVIL_DEFAULT_ACCOUNT = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266; //First public address used in Anvil

    function setUp() public {
        minimalAccount = new ZkMinimalAccount();
        minimalAccount.transferOwnership(ANVIL_DEFAULT_ACCOUNT); //Transfer ownership for signature signing with Anvil default key for tests
        usdc = new ERC20Mock();
        vm.deal(address(minimalAccount), 1e18);
    }

    function testZkOwnerCanExecuteCommands() public {
        //Arrange
        address dest = address(usdc);
        uint256 value = 0;

        //This is the actual action that we are calling
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);

        Transaction memory transaction =
            _createUnsignedTransaction(minimalAccount.owner(), 113, dest, value, functionData);

        //Act
        vm.prank(minimalAccount.owner());
        minimalAccount.executeTransaction(EMPTY_BYTES32, EMPTY_BYTES32, transaction);

        //Assert
        assertEq(usdc.balanceOf(address(minimalAccount)), AMOUNT);
    }

    function testZkNonOwnerCannotExecuteCommands() public {
        //Arrange
        address dest = address(usdc);
        uint256 value = 0;

        //This is the actual action that we are calling
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);

        Transaction memory transaction =
            _createUnsignedTransaction(minimalAccount.owner(), 113, dest, value, functionData);

        //Act, Assert
        vm.expectRevert(ZkMinimalAccount.ZkMinimalAccount__NotFromBootLoaderOrOwner.selector);
        vm.prank(Alice);
        minimalAccount.executeTransaction(EMPTY_BYTES32, EMPTY_BYTES32, transaction);
    }

    //This test has to be runned with the --system-mode=true flag as we are calling system contract
    function testZkValidateTransaction() public {
        //Arrange
        address dest = address(usdc);
        uint256 value = 0;

        //This is the actual action that we are calling
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);

        Transaction memory transaction =
            _createUnsignedTransaction(minimalAccount.owner(), 113, dest, value, functionData);

        transaction = _signedTransaction(transaction);

        //Act
        vm.prank(BOOTLOADER_FORMAL_ADDRESS); //Caling system contracts requires them to be from Bootloader
        bytes4 magic = minimalAccount.validateTransaction(EMPTY_BYTES32, EMPTY_BYTES32, transaction);

        //Assert
        assertEq(magic, ACCOUNT_VALIDATION_SUCCESS_MAGIC);
    }

    /////////////
    // HELPERS //
    /////////////

    function _createUnsignedTransaction(
        address from,
        uint8 transactionType,
        address to,
        uint256 value,
        bytes memory data
    ) internal view returns (Transaction memory) {
        uint256 nouce = vm.getNonce(address(minimalAccount));
        bytes32[] memory factoryDeps = new bytes32[](0);
        return Transaction({
            txType: transactionType, //we are doing type 113 (0x71)
            from: uint256(uint160(from)), //addresses are uint160, so we cast address to uint160 first, then to uint256
            to: uint256(uint160(to)),
            gasLimit: 16777216, //This is a rough number, if any problem with gas, we can tweak this
            gasPerPubdataByteLimit: 16777216,
            maxFeePerGas: 16777216,
            maxPriorityFeePerGas: 16777216,
            paymaster: 0, //not using paymaster
            nonce: nouce,
            value: value,
            reserved: [uint256(0), uint256(0), uint256(0), uint256(0)],
            data: data,
            signature: hex"", //hex"" == bytes("")
            factoryDeps: factoryDeps,
            paymasterInput: hex"",
            reservedDynamic: hex""
        });
    }

    function _signedTransaction(Transaction memory transaction) internal view returns (Transaction memory) {
        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 ANVIL_DEFAULT_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80; //Take anvil first address private key

        bytes32 unsignedTransactionHash = MemoryTransactionHelper.encodeHash(transaction); //Encode for us based on the transaction type
        (v, r, s) = vm.sign(ANVIL_DEFAULT_KEY, unsignedTransactionHash);
        Transaction memory signedTransaction = transaction;
        signedTransaction.signature = abi.encodePacked(r, s, v);
        return signedTransaction;
    }
}
