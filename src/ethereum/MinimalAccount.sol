// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAccount} from "@account-abstraction/contracts/interfaces/IAccount.sol";
import {PackedUserOperation} from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {Ownable} from "@openzeppelin-contracts/contracts/access/Ownable.sol";
import {MessageHashUtils} from "@openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "@openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {SIG_VALIDATION_FAILED, SIG_VALIDATION_SUCCESS} from "@account-abstraction/contracts/core/Helpers.sol";
import {IEntryPoint} from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";

/**
 * @title Account Abstraction Contract for Ethereum
 * @author Ronald Koh
 * @notice entrypoint will call this contract
 * @notice This MinimalAccount is an EIP-4337 smart wallet that proves ownership via ECDSA signatures,
 * only trusts EntryPoint for execution, pre-funds gas through EntryPoint escrow, and allows both AA-based
 * and owner-direct execution
 * @dev Bundlers are the nodes that run and maintain the alternative (AA) mempool and are capable of submitting
 * bundled UserOperations to Ethereum.
 * @dev Mental Model:
 *      User signs UserOperation (Offchain)
 *              ↓
 *      Bundler pays gas upfront
 *              ↓
 *      EntryPoint validates account
 *              ↓
 *      Account proves ownership
 *              ↓
 *      Account sends ETH → EntryPoint
 *              ↓
 *      EntryPoint executes call
 *              ↓
 *      EntryPoint reimburses bundler
 */
contract MinimalAccount is IAccount, Ownable {
    //////////////
    //  ERRORS  //
    //////////////
    error MinimalAccount__NotFromEntryPoint();
    error MinimalAccount__NotFromEntryPointOrOwner();
    error MinimalAccount__CallFailed(bytes);

    ///////////////////////
    //  STATE VARIABLES  //
    ///////////////////////
    IEntryPoint private immutable i_entryPoint;

    ////////////////
    //  MODIFIERS //
    ////////////////
    modifier requireFromEntryPoint() {
        if (msg.sender != address(i_entryPoint)) revert MinimalAccount__NotFromEntryPoint();
        _;
    }

    modifier requireFromEntryPointOrOwner() {
        if (msg.sender != address(i_entryPoint) && msg.sender != owner()) {
            revert MinimalAccount__NotFromEntryPointOrOwner();
        }
        _;
    }

    ////////////////
    //  FUNCTIONS //
    ////////////////
    constructor(address entryPoint) Ownable(msg.sender) {
        i_entryPoint = IEntryPoint(entryPoint);
    }

    //Allows the AA account to receive ETH
    //ETH can come from: owner, paymaster refund, another contract
    receive() external payable {}

    //////////////////////////
    //  EXTERNAL FUNCTIONS  //
    //////////////////////////

    /**
     * @notice To enable the calling of actions the EOA owner wants to do
     * @param dest The destination address/contract
     * @param value Value of ETH to send
     * @param functionData The actual action data
     */
    function execute(address dest, uint256 value, bytes calldata functionData) external requireFromEntryPointOrOwner {
        (bool success, bytes memory result) = dest.call{value: value}(functionData);
        if (!success) revert MinimalAccount__CallFailed(result);
    }

    /**
     * @param userOp The data structure of the information needed when submiting a txn, includes the signature
     * @param userOpHash The hashed version of the userOp
     * @param missingAccountFunds The gas fee to be paid to the ETH node when the Alt-mempool Nodes submits a txn
     * @dev A signature is valid, if it's the MinimalAccount owner
     * @dev Only the person that deploys this contract, can submit txns
     */
    function validateUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds)
        external
        requireFromEntryPoint
        returns (uint256 validationData)
    {
        //Based on IAccount's validateUserOp(), 0 for valid signature, 1 to mark signature failure
        validationData = _validateSignature(userOp, userOpHash);

        //nonce is used with the signature to prevent replay attacks (An attack using previously valid transaction or signed message to fraudulently perform the same action again)
        //and to enforce ordering/uniqueness of UserOperations
        //We can also validate nonce here, such as checking that nonce is sequential etc.
        //However, the actual nonce uniqueness is managed by EntryPoint.sol
        //Ideally, good to do nonce validation

        //Payback money to EntryPoint.sol
        _payPrefund(missingAccountFunds);
    }

    //////////////////////////
    //  INTERNAL FUNCTIONS  //
    //////////////////////////

    /**
     * @notice This function verifies that the signature is the owner based on the userOpHash and the Signature in userOp
     * @dev userOpHash has to be converted to the EIP-191 version of the signed Hash
     * @return validationData Return 1 for failed (not owner), and 0 for true (is owner)
     */
    function _validateSignature(PackedUserOperation calldata userOp, bytes32 userOpHash)
        internal
        view
        returns (uint256 validationData)
    {
        //This function converts the hash to the EIP-191 version
        //Which we can then use to recover the original signature of the message with ECDSA Recover
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(userOpHash);
        address signer = ECDSA.recover(ethSignedMessageHash, userOp.signature); //this will return who did the txn signing

        //Return values referenced from IAccount contract, validateUserOp()
        if (signer != owner()) return SIG_VALIDATION_FAILED; //returns 1, constant in AA import
        return SIG_VALIDATION_SUCCESS; //returns 0, constant in AA import
    }

    /**
     * @notice msg.sender here is the entryPoint, entryPoint holds the ETH temporarily, after execution entryPoint will reimburse the bundler
     * @notice NOT paying the mempool, we are funding EntryPoint’s escrow (an arrangement for a third party to hold the assets of a transaction temporarily)
     * @param missingAccountFund How much ETH is needed so the bundler doesn’t lose money
     */
    function _payPrefund(uint256 missingAccountFund) internal {
        if (missingAccountFund != 0) {
            (bool success,) = payable(msg.sender).call{value: missingAccountFund, gas: type(uint256).max}("");
            (success); //Not really needed but to prevent linter from underlining
        }
    }

    ///////////////
    //  GETTERS  //
    ///////////////

    function getEntryPoint() external view returns (address) {
        return address(i_entryPoint);
    }
}

// struct PackedUserOperation {
//     address sender;                   //the MinimalAccount owner (The person who deployed this AA address)
//     uint256 nonce;                    //nounce
//     bytes initCode;                   //ignore for now
//     bytes callData;                   //this is where we put the code logic/what we want to do in the txn
//     bytes32 accountGasLimits;         //gas limit
//     uint256 preVerificationGas;       //gas stuff
//     bytes32 gasFees;                  //gas fee
//     bytes paymasterAndData;           //by deafault, our AA contract will pay the mempool, but can customise someone else to pay the mempool which is here
//     bytes signature;                  //the signature to sign the entire data in the struct
// }
