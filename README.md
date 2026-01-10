## About this Project
1. Create a basic Account Abstraction (AA) on Ethereum
2. Create a basic Account Abstraction (AA) on zkSync
3. Deploy, and send a userOp / txn through them
    - Only will send a AA txn to zkSync
- AA allows us to define anything can sign a txn, not just a private key, can be google auth, group of users, etc.
- On Ethereum AA, the Entrypoint.sol contract will call handleOps() where the arguments will take in userOps
  - UserOps will hold the data such as the AA account address and the function that is to be executed

## Account Abstraction
- Known as EIP-4337
- Lets wallets replace private-key–only ownership with programmable verification logic, so accounts can be controlled using alternative authentication methods (like OAuth, passkeys, or multisig) instead of a single EOA key.
- EIP-4337 is a framework that everyone agrees upon when sending user operations.

#### 2 places where account abstraction exists:
1. Offical Account Abstraction contract deployed on the Ethereum Mainnet on March 1st 2023
   - Called EntryPoint.sol
   - Have to interact with this contract to do account abstraction

2. zkSync has Account Abstraction nativly implemented
 
### Account Abstraction with Ethereum
- Traditional Eth txn:
  - Sign data using wallet off chain
  - Spend gas to send this signed data on chain, otherwise known as a transaction 
  - Eth Node will then add the txn to a block

- Account Abstraction 
  - Deploy a smart contract that defines 'what' can sign transactions
  - 'what' - can be a group of people, google session key, etc.
  - This smart contract is then considered a wallet
  - When this Account Abstraction smart contract is signed, it sends a User Operation to an alt Mempool
    - To send a transaction, you send a "UserOp"

  - Alt-mempool Nodes, which is off chain, are a group of nodes that are facilitating the user operations
  - Alt-mempool Nodes are the ones paying gas, as they take the user operation, validate, and send the txn on chain
  - Alt-mempool Nodes are the ones doing the Traditional Eth txn
  - Alt-mempool Nodes sends the txn to the EntryPoint.sol smart contract, calling the handleOps()
    - Txn data associated with the user operation is passed to handleOps(), which includes pointing to the Account Abstraction smart contract deployed

    - EntryPoint.sol has optional "addons"
      - Signature Aggregator: Defines a group of signatures that needs to be aggregated 
      - Pay Master: Account Abstraction smart contract can be coded to have someone else pay the gas for the txn

### Account Abstraction with zkSync
- Similar to Ethereum Account Abstraction, but the zkSync Nodes are also the alt-mempool nodes

- Account Abstraction 
  - Deploy a smart contract that defines 'what' can sign transactions
  - 'what' - can be a group of people, google session key, etc.
  - This smart contract is then considered a wallet
  - When this Account Abstraction smart contract is signed, it sends a User Operation to an alt Mempool
    - To send a transaction, you send a "UserOp"

  - zkSync nodes are also the Alt-mempool Nodes
  - Alt-mempool Nodes facilitates the user operations
  - Alt-mempool Nodes are the ones paying gas, as they take the user operation, validate, and send the txn
  - Alt-mempool Nodes sends the txn to the EntryPoint.sol smart contract, calling the handleOps()
    - Txn data associated with the user operation is passed to handleOps(), which includes pointing to the Account Abstraction smart contract deployed

    - EntryPoint.sol has optional "addons"
      - Signature Aggregator: Defines a group of signatures that needs to be aggregated 
      - Pay Master: Account Abstraction smart contract can be coded to have someone else pay the gas for the txn

### zkSync AA
- To ensure we are working with foundry's zkSync environment (Because they dont use same evm and opcode as ETH)
  - foundryup-zksync
  - forge build --zksync

##### zkSync Test
- Tests requires --via-ir = true, in foundry.toml
- --via-ir stands for: Intermediate Representation
  - It tells the compiler to compile in Yul/assembly and then to EVM/REVM
  
- Tests that are calling sytem contracts requires --system-mode=true flag
  - forge test --mt testZkValidateTransaction --zksync --system-mode=true

#### System Contracts
- They are Smart Contracts deployed onto zkSync by deafult
- Their job is for deployment of smart contracts etc. onto zkSync
- https://docs.zksync.io/zksync-protocol/era-vm/contracts/system-contracts

#### Lifecycle of a type 113 (0x71) transaction (zkSync transaction lifecycle)
- When a AA txn is called, there is 2 phases in the lifecycle process;
 - When a type 113 txn is executed it is re-routed to the bootloader system contract
 - msg.sender will always be the bootloader contract (think of it as a super admin)
 
- Phase 1 Validation
  1. The user sends the txn to the "zkSync API client" (sort of a "light node")
  2. The zkSync API client checks to see the nounce is unique by querying the NounceHolder system contract
     1. 2a. System contracts are smart contracts deployed on zkSync by default
  3. The zkSync API client calls validateTransaction, which MUST update the nouce
  4. The zkSync API client checks that the nonce is updated, if not then the whole txn will revert
  5. The zkSync API client calls payForTransaction, or prepareForPaymaster & validateAndPayForPaymasterTransaction
  6.  The zkSync API client verifies that the bootloader gets paid
 
- Phase 2 Execution
  1. The zkSync API client passes the validated transaction to the main node/sequencer
  2. The main node calls executeTransaction()
  3. If a paymaster was used, the postTransaction is called
  
### Advanced Debug
- To view low-level opcode for debugging:
  - forge test --debug --mt (test name)
  - Shift G -> To reach line where code fails
  - Go backwards to debug the lines pior to failure 

### External Packages
- eth-infinitism/account-abstraction
  - https://github.com/eth-infinitism/account-abstraction
- OpenZeppelin/openzeppelin-contracts
  - https://github.com/OpenZeppelin/openzeppelin-contracts
- Cyfrin/foundry-era-contracts
  - https://github.com/Cyfrin/foundry-era-contracts
  - Used for ZKSync