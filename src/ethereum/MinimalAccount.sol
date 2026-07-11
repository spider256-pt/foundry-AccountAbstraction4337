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
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error MinimalAccount__NotFromEntryPoint();
    error MinimalAccount__NotFromEntryPointOrOwner();
    error MinimalAccount__CallFailed(bytes result);
    error MinimalAccount__PayPreFundFailed();

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    mapping(address => uint256) public nonces;
    IEntryPoint private immutable i_entryPoint;

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier requireFromEntryPoint() {
        if (msg.sender != address(i_entryPoint)) {
            revert MinimalAccount__NotFromEntryPoint();
        }
        _;
    }

    modifier requireFromEntryPointOrOwner() {
        if (msg.sender != address(i_entryPoint) && msg.sender != owner()) {
            revert MinimalAccount__NotFromEntryPointOrOwner();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    constructor(address entryPoint) Ownable(msg.sender) {
        i_entryPoint = IEntryPoint(entryPoint);
    }

    receive() external payable {}

    function _validateSignature(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    ) internal view returns (uint256 validation) {
        bytes32 ethSignedMessage = MessageHashUtils.toEthSignedMessageHash(
            userOpHash
        );
        address signer = ECDSA.recover(ethSignedMessage, userOp.signature); //Recovers the user key for verificatin purpose.

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
        if (missingAccountFunds != 0) {
            (bool success, ) = payable(msg.sender).call{
                value: missingAccountFunds,
                gas: type(uint256).max
            }("");
            if (!success) {
                revert MinimalAccount__PayPreFundFailed();
            }
        }
        if (validationData != SIG_VALIDATION_SUCCESS) {
            return validationData;
        }
        return validationData;
    }

    function execute(
        address dest,
        uint256 value,
        bytes calldata functiondata
    ) external payable requireFromEntryPointOrOwner {
        (bool success, bytes memory result) = dest.call{value: value}(
            functiondata
        );

        if (!success) {
            revert MinimalAccount__CallFailed(result);
        }
    }

    /*//////////////////////////////////////////////////////////////
                                GETTERS
    //////////////////////////////////////////////////////////////*/

    function getEntrtPoint() external view returns (address) {
        return address(i_entryPoint);
    }
}
