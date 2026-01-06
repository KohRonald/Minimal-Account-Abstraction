// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAccount} from "@foundry-era-contracts/system-contracts/contracts/interfaces/IAccount.sol";
import {Transaction} from "@foundry-era-contracts/system-contracts/contracts/libraries/MemoryTransactionHelper.sol";

/**
 * @title Minimal Account for ZK Sync
 * @author Ronald Koh
 * @notice Inherit IAccount AA functions
 * @notice IAccount functions are abstract as they are declared with a signature but lacks a body (implementation), terminating with a semicolon (;) instead of braces {}
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
    // Similar to validateUserOp() in ETH AA
    function validateTransaction(bytes32 _txHash, bytes32 _suggestedSignedHash, Transaction memory _transaction)
        external
        payable
        returns (bytes4 magic)
    {}

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
}
