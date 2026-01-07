// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAccount} from "@foundry-era-contracts/system-contracts/contracts/interfaces/IAccount.sol";
import {Transaction} from "@foundry-era-contracts/system-contracts/contracts/libraries/MemoryTransactionHelper.sol";
import {
    SystemContractsCaller
} from "@foundry-era-contracts/system-contracts/contracts/libraries/SystemContractsCaller.sol";
import {NONCE_HOLDER_SYSTEM_CONTRACT} from "@foundry-era-contracts/system-contracts/contracts/Constants.sol";
import {INouceHolder} from "@foundry-era-contracts/system-contracts/contracts/interfaces/INonceHolder.sol";

/**
 * @title Minimal Account for ZK Sync
 * @author Ronald Koh
 * @notice Inherit IAccount AA functions
 * @notice IAccount functions are abstract as they are declared with a signature but lacks a body (implementation), terminating with a semicolon (;) instead of braces {}
 * @dev When calling contract locally aded flag: --system-mode=true\
 * @dev --system-mode is needed as it is difficult to call system contract in zkSync.
 * @dev With that flag it will convert a specific data function (looks for "key phrase" which exists in a system contract) to a system contract call (zkSync Simulations)
 * @dev If no flag, then it will run that function as tho it is not a system contract
 * @dev When a AA txn is called, there is 2 phases in the lifecycle process;
 *      Lifecycle of a type 113 (0x71) transaction
 *          - When a type 113 txn is executed it is re-routed to the bootloader system contract
 *          - msg.sender will always be the bootloader contract (think of it as a super admin)
 *
 *      - Phase 1 Validation
 *              1. The user sends the txn to the "zkSync API client" (sort of a "light node")
 *              2. The zkSync API client checks to see the nounce is unique by querying the NounceHolder system contract
 *                  2a. System contracts are smart contracts deployed on zkSync by default
 *              3. The zkSync API client calls validateTransaction, which MUST update the nouce
 *              4. The zkSync API client checks that the nonce is updated, if not then the whole txn will revert
 *              5. The zkSync API client calls payForTransaction, or prepareForPaymaster & validateAndPayForPaymasterTransaction
 *              6. The zkSync API client verifies that the bootloader gets paid
 *
 *      - Phase 2 Execution
 *             1. The zkSync API client passes the validated transaction to the main node/sequencer
 *             2. The main node calls executeTransaction()
 *             3. If a paymaster was used, the postTransaction is called
 */
contract ZkMinimalAccount is IAccount {
    ////////////////////////
    // EXTERNAL FUNCTIONS //
    ////////////////////////

    /**
     * @notice Must increment nouce
     * @notice must validate transaction (check the owner signed the txn)
     * @notice Check to see if we have enough money in our account to pay for the txn
     * @param _txHash .
     * @param _suggestedSignedHash .
     * @param _transaction .
     */
    // Similar to validateUserOp() in ETH AA
    function validateTransaction(bytes32 _txHash, bytes32 _suggestedSignedHash, Transaction memory _transaction)
        external
        payable
        returns (bytes4 magic)
    {
        // Call nouceholder
        // Increment nouce

        //This does the system call to do the above
        //We ignore the return data
        SystemContractsCaller.systemCallWithPropagatedRevert(
            uint32(gasleft()),
            address(NONCE_HOLDER_SYSTEM_CONTRACT), //This is the nonceholder system contract
            0,
            abi.encodeCall(INonceHolder.incrementMinNonceIfEquals, (_transaction.nonce)) //This calls the nonce increment function found in nonceholder contract to increment the current _transaction nonce
        );
    }

    // Similar to execute() in ETH AA
    // Function access: Only the owner/bootloader system contract is able to call this
    function executeTransaction(bytes32 _txHash, bytes32 _suggestedSignedHash, Transaction memory _transaction)
        external
        payable {}

    // Allows another user to excute a txn that is validated by the user beforehand
    // You sign a txn, send the signed txn to a friend, they can send it by calling this function
    // Function access: Other users can call this
    function executeTransactionFromOutside(Transaction memory _transaction) external payable {}

    // Similar to _payPrefund() in ETH AA
    function payForTransaction(bytes32 _txHash, bytes32 _suggestedSignedHash, Transaction memory _transaction)
        external
        payable {}

    // This function gets called first before payForTransaction(), if there is a paymaster setup
    function prepareForPaymaster(bytes32 _txHash, bytes32 _possibleSignedHash, Transaction memory _transaction)
        external
        payable {}

    ////////////////////////
    // INTERNAL FUNCTIONS //
    ////////////////////////
}
