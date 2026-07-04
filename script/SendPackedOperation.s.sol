//SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";

import {HelperConfig} from "../script/HelperConfig.s.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";

using MessageHashUtils for bytes32;

contract SendPackedOperation is Script {
    HelperConfig public helperConfig;
    function run() external {}

    function setUp() public {
        helperConfig = new HelperConfig();
    }

    function setHelperConfig(HelperConfig _helperConfig) public {
        helperConfig = _helperConfig;
    }

    function generatedSingnatureOperation(
        bytes memory callData,
        HelperConfig.NetworkConfig memory config,
        address minimalAccount
    ) public returns (PackedUserOperation memory) {
        uint256 nonce = vm.getNonce(minimalAccount) - 1;
        PackedUserOperation memory unsignedUserOp = _generateUnsignedUserOp(callData, minimalAccount, nonce);

        bytes32 userOpHash = IEntryPoint(config.entryPoint).getUserOpHash(unsignedUserOp);

        bytes32 digest = userOpHash.toEthSignedMessageHash();

        uint8 v;
        bytes32 r;
        bytes32 s;

        uint256 ANVIL_DEFAULT_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

        if (block.chainid == 31337) {
            (v, r, s) = vm.sign(ANVIL_DEFAULT_KEY, digest);
        } else {
            (v, r, s) = vm.sign(vm.envUint("PRIVATE_KEY"), digest);
        }
        unsignedUserOp.signature = abi.encodePacked(r, s, v);

        return unsignedUserOp;
    }

    function _generateUnsignedUserOp(bytes memory callData, address sender, uint256 nonce)
        internal
        pure
        returns (PackedUserOperation memory)
    {
        uint256 verificationGasLimit = 200000;
        uint256 callGasLimit = 300000;
        uint256 maxFeePerGas = 100 gwei;
        uint256 maxPriorityFeePerGas = 2 gwei;

        return PackedUserOperation({
            sender: sender,
            nonce: nonce,
            initCode: hex"",
            callData: callData,
            accountGasLimits: bytes32((uint256(verificationGasLimit) << 128) | callGasLimit),
            preVerificationGas: verificationGasLimit + 500000,
            gasFees: bytes32((uint256(maxPriorityFeePerGas) << 128) | maxFeePerGas),
            paymasterAndData: hex"",
            signature: hex""
        });
    }
}
