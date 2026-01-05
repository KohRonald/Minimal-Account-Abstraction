// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAccount} from "@foundry-era-contracts/system-contracts/contracts/interfaces/IAccount.sol";
import {Transaction} from "@foundry-era-contracts/system-contracts/contracts/libraries/MemoryTransactionHelper.sol";

/*
 * @title Minimal Account for ZK Sync
 * @author Ronald Koh
 * @notice Inheit IAccount AA functions
 * @notice IAccuntion functions are abstract as they are declared with a signature but lacks a body (implementation), terminating with a semicolon (;) instead of braces {}
 */
contract ZkMinimalAccount is IAccount {
    function validateTransaction(bytes32 _txHash, bytes32 _suggestedSignedHash, Transaction calldata _transaction)
        external
        payable
        returns (bytes4 magic)
    {}

    function executeTransaction(bytes32 _txHash, bytes32 _suggestedSignedHash, Transaction calldata _transaction)
        external
        payable {}

    function executeTransactionFromOutside(Transaction calldata _transaction) external payable {}

    function payForTransaction(bytes32 _txHash, bytes32 _suggestedSignedHash, Transaction calldata _transaction)
        external
        payable {}

    function prepareForPaymaster(bytes32 _txHash, bytes32 _possibleSignedHash, Transaction calldata _transaction)
        external
        payable {}
}
