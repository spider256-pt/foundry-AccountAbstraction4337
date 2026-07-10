//SPDX-License-Identifer:MIT

pragma solidity ^0.8.24;

import {
    IAccount,
    ACCOUNT_VALIDATION_SUCCESS_MAGIC
} from "lib/foundry-era-contracts/src/system-contracts/contracts/interfaces/IAccount.sol";
import {
    Transaction,
    MemoryTransactionHelper
} from "lib/foundry-era-contracts/src/system-contracts/contracts/libraries/MemoryTransactionHelper.sol";

import {
    SystemContractsCaller
} from "lib/foundry-era-contracts/src/system-contracts/contracts/libraries/SystemContractsCaller.sol";

import {
    NONCE_HOLDER_SYSTEM_CONTRACT,
    BOOTLOADER_FORMAL_ADDRESS
} from "lib/foundry-era-contracts/src/system-contracts/contracts/Constants.sol";

import {
    INonceHolder
} from "lib/foundry-era-contracts/src/system-contracts/contracts/interfaces/INonceHolder.sol";

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {
    MessageHashUtils
} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract ZkMinimalAccount is IAccount, Ownable {
    using MemoryTransactionHelper for Transaction;
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    bytes4 magic;

    constructor() Ownable(msg.sender) {}

    error zkSyncAccount__NotEnoughBalance();
    error zkMinimalAccount__NotFromBootloader();

    modifier requireFromBootloader() {
        if (msg.sender != BOOTLOADER_FORMAL_ADDRESS) {
            revert zkMinimalAccount__NotFromBootloader();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTION
    //////////////////////////////////////////////////////////////*/

    /**
     * Lifecycle of a type 113(0x71) transaction.
     *
     * Phase 1 validation
     * 1. The user sends the transaction to the "zkSync API client".
     * 2. the zkSync API client checks to see the nonce is unique by quering to the NonceHolder system contract.
     * 3. the zksync API client calls validateTransaction, which must update the Nonce.
     * 4. the zksync API client checks the nonce is updated.
     * 5. the zksync API client calls payForTransaction or prepareForPaymaster and validateandPayforPaymasterTransaction.
     * 6. The zksync API client verifies the bootloader get paid.
     *
     *
     * Phase 2 Execution
     *
     * 7. zkSync API client passes the validated transacton to the main node.
     * 8. The main node calls the executeTransaction.
     * 9. If paymaster is used then the postTransaction is called.

     */
    function validateTransaction(
        bytes32 _txHash,
        bytes32 _suggestedSignedHash,
        Transaction calldata _transaction
    ) external payable override requireFromBootloader returns (bytes4 magic) {
        //Validartes the nonce for prventing replay attacks.
        SystemContractsCaller.systemCallWithPropagatedRevert(
            uint32(gasleft()),
            address(NONCE_HOLDER_SYSTEM_CONTRACT),
            0,
            abi.encodeCall(
                INonceHolder.incrementMinNonceIfEquals,
                (_transaction.nonce)
            )
        );
        //Validates the balance for transaction fee.
        uint256 totalRequiredBalance = _transaction.totalRequiredBalance();
        if (totalRequiredBalance > address(this).balance) {
            revert zkSyncAccount__NotEnoughBalance();
        }

        //Validates the signer for EOA or smart contract acccounts.
        bytes32 txHash = _transaction.encodeHash();
        address signer = ECDSA.recover(txHash, _transaction.signature);
        bool isValidSigner = signer == owner();

        if (isValidSigner) {
            magic = ACCOUNT_VALIDATION_SUCCESS_MAGIC;
        } else {
            magic = bytes4(0);
        }
        return magic;
    }

    function executeTransaction(
        bytes32 _txHash,
        bytes32 _suggestedSignedHash,
        Transaction calldata _transaction
    ) external payable override {
        //logic
    }
    function executeTransactionFromOutside(
        Transaction calldata _transaction
    ) external payable override {
        //logic
    }

    function payForTransaction(
        bytes32 _txHash,
        bytes32 _suggestedSignedHash,
        Transaction calldata _transaction
    ) external payable override {
        //logic
    }

    function prepareForPaymaster(
        bytes32 _txHash,
        bytes32 _possibleSignedHash,
        Transaction calldata _transaction
    ) external payable override {
        //logic
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTION
    //////////////////////////////////////////////////////////////*/
}
