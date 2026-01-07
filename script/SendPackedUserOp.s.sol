// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {PackedUserOperation} from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {IEntryPoint} from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {MessageHashUtils} from "@openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import {IERC20} from "@openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {MinimalAccount} from "src/ethereum/MinimalAccount.sol";

contract SendPackedUserOps is Script {
    using MessageHashUtils for bytes32;
    address constant BURNER_WALLET = 0x8C1074Aa2Bb05D632d5C5276b7ea2C21e4975aE6; //TestNet metamask wallet
    address minimalAccount = 0x0000000000000000000000000000000000000000; //This should be the contract of the deployed minimalAccount

    function run() public {
        // HelperConfig helperConfig = new HelperConfig();
        // address dest_arbitrum_usdc = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831; //L1 USDC end point address
        // uint256 value = 0;
        // bytes memory functionData = abi.encodeWithSelector(IERC20.approve.selector, BURNER_WALLET, 1e18);
        // bytes memory executeCalldata =
        //     abi.encodeWithSelector(MinimalAccount.execute.selector, dest, value, functionData);
        // PackedUserOperation memory userOp =
        //     generateSignedUserOperation(executeCalldata, helperConfig.getConfig(), minimalAccount);
        // PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        // ops[0] = userOp;

        // vm.startBroadcast();
        // IEntryPoint(helperConfig.getConfig().entryPoint).handleOps(ops, payable(helperConfig.getConfig().account));
        // vm.stopBroadcast();
    }

    /**
     * @return PackedUserOperation - In memory as it is a struct
     */
    function generateSignedUserOperation(
        bytes memory callData,
        HelperConfig.NetworkConfig memory config,
        address minimalAccount
    ) public view returns (PackedUserOperation memory) {
        //1. Generate unsigned Data
        uint256 nonce = vm.getNonce(minimalAccount) - 1; //use vm cheatcode to get nonce, -1 as the entryPoint contract also has gets nonce, and to prevent clash we minus 1 from here, where this nonce is recieed first before entryPoint contract gets theirs
        PackedUserOperation memory userOp = _generateUnsignedUserOperations(callData, minimalAccount, nonce);

        //2. Get User Operations hash
        bytes32 userOpHash = IEntryPoint(config.entryPoint).getUserOpHash(userOp);

        //same as doing MessageHashUtils.toEthSignedMessageHash(userOpHash)
        // Returns the keccak256 digest of an ERC-191 signed data
        bytes32 digest = userOpHash.toEthSignedMessageHash(); //convert to ETH signed message hash

        //3. Sign the data, and return
        //takes in the private key and the message digest
        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 ANVIL_DEFAULT_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80; //Take anvil first address private key
        if (block.chainid == 31337) {
            (v, r, s) = vm.sign(ANVIL_DEFAULT_KEY, digest);
        } else {
            (v, r, s) = vm.sign(config.account, digest);
        }

        //when we use config.account(the public address) for the private key arg, foundry will check if they have the private key unlocked. If yes, then will use that private key to sign.
        //if no wallets are unlocked, then error will be "vm.sign: no wallets available"
        //Testing on local anvil chain, will encounter this error, unless there is the if statement to use anvil deafult key as written above

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
