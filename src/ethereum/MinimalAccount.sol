//SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {
    IAccount
} from "lib/account-abstraction/contracts/interfaces/IAccount.sol";

import {
    IEntryPoint
} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";

import {
    PackedUserOperation
} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";

import {
    SIG_VALIDATION_FAILED,
    SIG_VALIDATION_SUCCESS
} from "lib/account-abstraction/contracts/core/Helpers.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import {
    MessageHashUtils
} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract MinimalAccount is IAccount, Ownable {
    mapping(address => uint256) public nonces;
    IEntryPoint private immutable i_entryPoint;

    error MinimalAccount__NotFromEntryPoint();

    constructor(address entryPoint) Ownable(msg.sender) {
        i_entryPoint = IEntryPoint(entryPoint);
    }

    modifier requireFromEntryPoint() {
        if (msg.sender != address(i_entryPoint)) {
            revert MinimalAccount__NotFromEntryPoint();
        }
        _;
    }

    function _validateSignature(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    ) internal view returns (uint256 validation) {
        bytes32 ethSignedMessage = MessageHashUtils.toEthSignedMessageHash(
            userOpHash
        );
        address signer = ECDSA.recover(ethSignedMessage, userOp.signature);

        if (signer == address(0) || signer != owner()) {
            return SIG_VALIDATION_FAILED; //If falied returns 1
        }

        return SIG_VALIDATION_SUCCESS; // If Passed returns 0
    }

    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external override requireFromEntryPoint returns (uint256 validationData) {
        validationData = _validateSignature(userOp, userOpHash);
        if (validationData != SIG_VALIDATION_SUCCESS) {
            return validationData;
        }
        return validationData;
    }

    /*//////////////////////////////////////////////////////////////
                                GETTERS
    //////////////////////////////////////////////////////////////*/

    function getEntrtPoint() external view returns (address) {
        return address(i_entryPoint);
    }
}
