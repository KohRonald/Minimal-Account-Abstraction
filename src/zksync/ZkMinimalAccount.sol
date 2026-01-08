// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// zkSync Era Imports
import {
    IAccount,
    ACCOUNT_VALIDATION_SUCCESS_MAGIC
} from "@foundry-era-contracts/system-contracts/contracts/interfaces/IAccount.sol";
import {
    Transaction,
    MemoryTransactionHelper
} from "@foundry-era-contracts/system-contracts/contracts/libraries/MemoryTransactionHelper.sol";
import {
    SystemContractsCaller
} from "@foundry-era-contracts/system-contracts/contracts/libraries/SystemContractsCaller.sol";
import {
    NONCE_HOLDER_SYSTEM_CONTRACT,
    BOOTLOADER_FORMAL_ADDRESS,
    DEPLOYER_SYSTEM_CONTRACT
} from "@foundry-era-contracts/system-contracts/contracts/Constants.sol";
import {INouceHolder} from "@foundry-era-contracts/system-contracts/contracts/interfaces/INonceHolder.sol";
import {Utils} from "@foundry-era-contracts/system-contracts/contracts/libraries/Utils.sol";

//OZ Imports
import {MessageHashUtils} from "@openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "@openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {Ownable} from "@openzeppelin-contracts/contracts/access/Ownable.sol";

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
contract ZkMinimalAccount is IAccount, Ownable {
    using MemoryTransactionHelper for Transaction;

    error ZkMinimalAccount__NotEnoughBalance();
    error ZkMinimalAccount__NotFromBootLoader();
    error ZkMinimalAccount__ExecutionFailed();
    error ZkMinimalAccount__NotFromBootLoaderOrOwner();

    //////////////
    // MODIFIER //
    /////////////
    modifier requireFromBootLoader() {
        if (msg.sender != BOOTLOADER_FORMAL_ADDRESS) {
            revert ZkMinimalAccount__NotFromBootLoader();
        }
        _;
    }

    modifier requireFromBootLoaderOrOwner() {
        if (msg.sender != BOOTLOADER_FORMAL_ADDRESS && msg.sender != owner()) {
            revert ZkMinimalAccount__NotFromBootLoaderOrOwner();
        }
        _;
    }

    constructor() Ownable(msg.sender) {}

    ////////////////////////
    // EXTERNAL FUNCTIONS //
    ////////////////////////

    /**
     * @notice zkSync allows for control over nonce, while eth does not
     * @notice Only Bootloader can call this function to update our nonce
     * @notice Must increment nouce
     * @notice must validate transaction (check the owner signed the txn)
     * @notice Check to see if we have enough money in our account to pay for the txn
     * @param _txHash Ignore for now
     * @param _suggestedSignedHash Ignore for now
     * @param _transaction .
     * @return magic The indicator on the state of validateTransaction, similar to boolean true/false
     */
    // Similar to validateUserOp() in ETH AA
    function validateTransaction(
        bytes32,
        /*_txHash*/
        bytes32,
        /*_suggestedSignedHash*/
        Transaction memory _transaction
    )
        external
        payable
        requireFromBootLoader
        returns (bytes4 magic)
    {
        // Call nonceholder
        // Increment nouce

        //This does the system contract call to do the above
        //We ignore the return data
        //NONCE_HOLDER_SYSTEM_CONTRACT controls all the nounces
        //NONCE_HOLDER_SYSTEM_CONTRACT is the address
        //INonceHolder is the interface of NONCE_HOLDER_SYSTEM_CONTRACT
        SystemContractsCaller.systemCallWithPropagatedRevert(
            uint32(gasleft()), //We return the remaining gas of the contract call
            address(NONCE_HOLDER_SYSTEM_CONTRACT), //This is the nonceholder system contract
            0,
            abi.encodeCall(INonceHolder.incrementMinNonceIfEquals, (_transaction.nonce)) //This calls the nonce increment function found in nonceholder contract to increment the current _transaction nonce
        );

        // Check for fee to pay
        // MemoryTransactionHelper libary helper function will help calculate the fee
        uint256 totalRequiredBalance = _transaction.totalRequiredBalance();
        if (totalRequiredBalance > address(this).balance) {
            revert ZkMinimalAccount__NotEnoughBalance();
        }

        // Check the signature
        // MemoryTransactionHelper libary helper function will help calculate the suggested signed hash of the transaction
        bytes32 txHash = _transaction.encodeHash();
        address signer = ECDSA.recover(txHash, _transaction.signature);
        bool isValidSigner = signer == owner();

        //Return the "magic" number
        if (isValidSigner) {
            magic = ACCOUNT_VALIDATION_SUCCESS_MAGIC; //equivalent of saying True
        } else {
            magic = bytes4(0); //This is 0x00000000, equivalent of saying False
        }

        return magic;
    }

    // Similar to execute() in ETH AA
    // Function access: Only the owner/bootloader system contract is able to call this
    // This function is called by the sequencer after validateTransaction() passed
    function executeTransaction(
        bytes32,
        /*_txHash*/
        bytes32,
        /*_suggestedSignedHash*/
        Transaction memory _transaction
    )
        external
        payable
        requireFromBootLoaderOrOwner
    {
        address to = address(uint160(_transaction.to)); //addresses are uint160, 'to' value is a uint256, so we cast it
        uint128 value = Utils.safeCastToU128(_transaction.value); //cast to uint128, as system contract call takes uint128
        bytes memory data = _transaction.data;

        //If deploying a contract, use the SystemContractsCaller library, as contract deployment calls system contracts to faciliate deployments
        if (to == address(DEPLOYER_SYSTEM_CONTRACT)) {
            uint32 gas = Utils.safeCastToU32(gasleft());
            SystemContractsCaller.systemCallWithPropagatedRevert(gas, to, value, data);
        } else {
            //Otherwise if not deploying a contract
            bool success;
            // Making a call in assembly which is similar to:
            //(bool success, bytes memory result) = dest.call{value: value}(functionData);
            assembly {
                success := call(gas(), to, value, add(data, 0x20), mload(data), 0, 0)
            }
            if (!success) {
                revert ZkMinimalAccount__ExecutionFailed();
            }
        }
    }

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
