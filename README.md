## About this Project
1. Create a basic Account Abstraction (AA) on Ethereum
2. Create a basic Account Abstraction (AA) on zkSync
3. Deploy, and send a userOp / txn through them
    - Only will send a AA txn to zkSync
- AA allows us to define anything can sign a txn, not just a private key, can be google auth, group of users, etc.
- On Ethereum AA, the Entrypoint.sol contract will call handleOps() where the arguments will take in userOps.
  - UserOps will hold the data such as the AA account address and the function that is to be executed.

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
  
### Advanced Debug
- To view low-level opcode for debugging:
  - forge test --debug --mt (test name)
  - Shift G -> To reach line where code fails
  - Go backwards to debug the lines pior to failure 