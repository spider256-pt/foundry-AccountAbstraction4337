# 🚀 Account Abstraction (ERC-4337 & zkSync Native)

An advanced, dual-architecture implementation of Account Abstraction. This repository contains custom smart accounts built for both standard Ethereum EVM (via ERC-4337) and zkSync Era's native protocol-level Account Abstraction. 

Built as a proof-of-work portfolio piece for deep EVM security research, smart contract auditing, and next-generation transaction routing.

## 🧠 Architecture Overview

This project implements and contrasts two fundamentally different approaches to Account Abstraction:

### 1. Ethereum Standard (ERC-4337)
* **Application-Layer Implementation:** Uses the standardized `EntryPoint.sol` contract as the global router and validation gatekeeper.
* **Key Contracts:** `MinimalAccount.sol`
* **Features:** Standard ECDSA signature recovery, `PackedUserOperation` formatting, EVM nonce tracking, and dynamic gas pre-funding mechanisms.

### 2. zkSync Era (Native AA)
* **Protocol-Layer Implementation:** Bypasses external entry points and alt-mempools. Smart accounts are treated as first-class citizens at the operating system level via the EraVM **Bootloader**.
* **Key Contracts:** `ZkMinimalAccount.sol`
* **Features:** Integration with zkSync `SystemContractsCaller`, native `NonceHolder` manipulation, protocol-level `validateTransaction` flows, and EIP-712 structured data signing.

## 🛠️ Prerequisites

* [Foundry](https://getfoundry.sh/) (Forge, Anvil, Cast)
* [foundry-zksync](https://foundry-book.zksync.io/) (For EraVM compilation and testing)
* Make (optional, for scripting)

## 📦 Installation

Clone the repository and install the required dependencies (OpenZeppelin and Account Abstraction interfaces):

```bash
git clone <your-repo-url>
cd AccountAbstraction4337
forge install

🧪 Testing
Because this repository contains both standard EVM and zkSync EraVM logic, tests must be isolated to prevent compiler cross-contamination.

Test the Ethereum ERC-4337 Implementation:
Uses the standard solc compiler.

Bash
forge test --match-contract MinimalAccountTest -vvvv
Test the zkSync Native Implementation:
Requires the --zksync flag to utilize the zksolc compiler and bypass standard EVM stack limits.

Bash
forge test --match-contract TestzkSyncMinimalAccount --zksync --via-ir -vvvv
🚀 Deployment & Interaction
The script/ directory contains dynamic deployment and execution scripts utilizing a custom HelperConfig.s.sol to seamlessly switch between local Anvil instances and live testnets (e.g., Sepolia).

1. Deploy the Account
Deploy a fresh MinimalAccount and transfer ownership to your signing wallet:

Bash
forge script script/DeployMinimal.s.sol --rpc-url $ETH_SEPOLIA --private-key$PRIVATE_KEY --broadcast
2. Execute a User Operation
Construct, sign, and broadcast a PackedUserOperation (e.g., executing an ERC-20 token approval) through the official EntryPoint:

Bash
# Ensure your MinimalAccount address and EntryPoint nonce logic are updated in the script before running
forge script script/SendPackedOperation.s.sol --rpc-url $ETH_SEPOLIA --private-key$PRIVATE_KEY --broadcast
🛡️ Security & Auditing Focus
This repository is built with a strict focus on smart contract security and vulnerability research. Key audit considerations implemented within the code include:

Signature Replay Protection: Enforcing strict, mathematically unique nonce tracking across both EVM and EraVM system contracts.

Ownership Hijacking Prevention: Secure initialization and constructor parameterization.

Gas Exhaustion Defenses: Overriding strict pre-verification gas limits to prevent Out-Of-Gas (OOG) execution drops during live network simulation.

Validation Gatekeeping: Enforcing requireFromBootloader modifiers on zkSync to prevent malicious EOA transaction spoofing.

Developed by Pratik Das | Focused on the elite horizon of Web3 Security & Auditing.