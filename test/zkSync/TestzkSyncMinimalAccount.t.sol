//SPDX-License-Identofier: MIT

pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {ZkMinimalAccount} from "../../src/zksync/ZkMinimalAccount.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {
    Transaction,
    MemoryTransactionHelper
} from "lib/foundry-era-contracts/src/system-contracts/contracts/libraries/MemoryTransactionHelper.sol";

import {
    MessageHashUtils
} from "@openzeppelin/contracts/utils/Cryptography/MessageHashUtils.sol";

import {
    BOOTLOADER_FORMAL_ADDRESS
} from "lib/foundry-era-contracts/src/system-contracts/contracts/Constants.sol";

import {
    IAccount,
    ACCOUNT_VALIDATION_SUCCESS_MAGIC
} from "lib/foundry-era-contracts/src/system-contracts/contracts/interfaces/IAccount.sol";

contract TestzkSyncMinimalAccount is Test {
    using MessageHashUtils for bytes32;

    ZkMinimalAccount minimalAccount;
    ERC20Mock usdc;
    uint256 constant AMOUNT = 1e18;
    bytes32 constant EMPTY_BYTES32 = bytes32(0);

    address constant ANVIL_ADDRESS = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    uint256 constant ANVIL_PRIVATE_KEY =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    function setUp() public {
        minimalAccount = new ZkMinimalAccount();
        minimalAccount.transferOwnership(ANVIL_ADDRESS);
        usdc = new ERC20Mock();
        vm.deal(address(minimalAccount), AMOUNT);
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function _createUnsignedTransaction(
        address from,
        uint8 transactionType,
        address to,
        uint256 value,
        bytes memory data
    ) internal view returns (Transaction memory) {
        uint256 nonce = vm.getNonce(address(minimalAccount));
        bytes32[] memory factoryDeps = new bytes32[](0);

        return
            Transaction({
                txType: transactionType,
                from: uint256(uint160(from)),
                to: uint256(uint160(to)),
                gasLimit: 1000000,
                gasPerPubdataByteLimit: 800,
                maxFeePerGas: 100000000,
                maxPriorityFeePerGas: 0,
                paymaster: 0,
                nonce: nonce,
                value: value,
                reserved: [uint256(0), uint256(0), uint256(0), uint256(0)],
                data: data,
                signature: bytes(""),
                factoryDeps: new bytes32[](0),
                paymasterInput: bytes(""),
                reservedDynamic: bytes("")
            });
    }

    function _signTransaction(
        Transaction memory transaction
    ) internal view returns (Transaction memory) {
        bytes32 unsignedTransactionHash = MemoryTransactionHelper.encodeHash(
            transaction
        );
        bytes32 digest = unsignedTransactionHash.toEthSignedMessageHash();

        uint8 v;
        bytes32 r;
        bytes32 s;
        (v, r, s) = vm.sign(ANVIL_PRIVATE_KEY, unsignedTransactionHash);
        Transaction memory signedTransaction = transaction;
        signedTransaction.signature = abi.encodePacked(r, s, v);

        return signedTransaction;
    }

    /*//////////////////////////////////////////////////////////////
                             FUNCTIONALLITY
    //////////////////////////////////////////////////////////////*/

    function testZkOwnerCanExecuteCommands() public {
        //Arrange
        address dest = address(usdc);
        uint256 value = 0;

        bytes memory functionData = abi.encodeWithSelector(
            ERC20Mock.mint.selector,
            address(minimalAccount),
            AMOUNT
        );
        //Act
        Transaction memory transaction = _createUnsignedTransaction(
            minimalAccount.owner(),
            113,
            dest,
            value,
            functionData
        );

        vm.prank(minimalAccount.owner());
        minimalAccount.executeTransaction(
            EMPTY_BYTES32,
            EMPTY_BYTES32,
            transaction
        );

        //Assert
        assertEq(
            usdc.balanceOf(address(minimalAccount)),
            AMOUNT,
            "USDC balance should increase"
        );
    }

    function testValidateTransaction() public {
        //Arrange
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(
            usdc.mint.selector,
            address(minimalAccount),
            AMOUNT
        );
        Transaction memory transaction = _createUnsignedTransaction(
            minimalAccount.owner(),
            113,
            dest,
            value,
            functionData
        );

        transaction = _signTransaction(transaction);
        //Act
        vm.prank(BOOTLOADER_FORMAL_ADDRESS);
        bytes4 magic = minimalAccount.validateTransaction(
            EMPTY_BYTES32,
            EMPTY_BYTES32,
            transaction
        );
        //Assert
        assertEq(
            magic,
            ACCOUNT_VALIDATION_SUCCESS_MAGIC,
            "Validatation did not success"
        );
    }
}
