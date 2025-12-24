// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {PackedUserOperation} from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {IEntryPoint} from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {MessageHashUtils} from "@openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";

contract SendPackedUserOps is Script {
    using MessageHashUtils for bytes32;

    function run() public {}

    /**
     * @return PackedUserOperation - In memory as it is a struct
     */
    function generateSignedUserOperation(bytes memory callData, HelperConfig.NetworkConfig memory config)
        public
        view
        returns (PackedUserOperation memory)
    {
        //1. Generate unsigned Data
        uint256 nonce = vm.getNonce(config.account); //use vm cheatcode to get nonce
        PackedUserOperation memory userOp = _generateUnsignedUserOperations(callData, config.account, nonce);

        //2. Get User Operations hash
        bytes32 userOpHash = IEntryPoint(config.entryPoint).getUserOpHash(userOp);

        //same as doing MessageHashUtils.toEthSignedMessageHash(userOpHash)
        // Returns the keccak256 digest of an ERC-191 signed data
        bytes32 digest = userOpHash.toEthSignedMessageHash(); //convert to ETH signed message hash

        //3. Sign the data, and return
        //takes in the private key and the message digest
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(config.account, digest);
        //when we use config.account(the public address) for the private key arg, foundry will check if they have the private key unlocked. If yes, then will use that private key to sign.
        //if no wallets are unlocked, then error will be "vm.sign: no wallets available"
        //Testing on local anvil chain, will encounter this error

        //3a. Insert the signature into the PackedUserOperation struct
        userOp.signature = abi.encodePacked(r, s, v); //Note the order

        return userOp;
    }

    /**
     *
     * @param callData The function call of that userOperation
     * @return PackedUserOperation - Return the struct with the Signature blank
     */
    function _generateUnsignedUserOperations(bytes memory callData, address sender, uint256 nonce)
        internal
        pure
        returns (PackedUserOperation memory)
    {
        uint128 verificationGasLimit = 16777216; //This is a rough number, if any problem with gas, we can tweak this
        uint128 callGasLimit = verificationGasLimit;
        uint128 maxPriorityFeePerGas = 256; //This is a rough number, if any problem with gas, we can tweak this
        uint128 maxFeePerGas = maxPriorityFeePerGas;

        return PackedUserOperation({
            sender: sender,
            nonce: nonce,
            initCode: hex"", //ignore for now as we are not initialising any contract, hex"" == bytes("")
            callData: callData, //this holds our function data to call
            accountGasLimits: bytes32(uint256(verificationGasLimit) << 128 | callGasLimit), //combining verificationGasLimit and callGasLimit into bytes32
            preVerificationGas: verificationGasLimit,
            gasFees: bytes32(uint256(maxPriorityFeePerGas) << 128 | maxFeePerGas), //combining maxPriorityFeePerGas and maxFeePerGas into bytes32
            paymasterAndData: hex"", //we do not have paymaster, hex"" == bytes("")
            signature: hex""
        });
    }
}
