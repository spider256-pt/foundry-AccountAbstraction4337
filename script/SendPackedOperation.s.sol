//SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {MinimalAccount} from "../src/ethereum/MinimalAccount.sol";

import {Script} from "forge-std/Script.sol";

import {HelperConfig} from "../script/HelperConfig.s.sol";
import {
    IEntryPoint
} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {
    MessageHashUtils
} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import {
    PackedUserOperation
} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

using MessageHashUtils for bytes32;

contract SendPackedOperation is Script {
    HelperConfig public helperConfig;
    function run() external {
        helperConfig = new HelperConfig();
        address minimalAccount = address(
            0x69361F9919B67BB27Dc4D0c64773c7e1d865753E
        );

        address dest = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
        uint256 value = 0;

        bytes memory functionData = abi.encodeWithSelector(
            IERC20.approve.selector,
            0x5f265547093b1c70011b5036C77A5378a7D9c8eA,
            1e18
        );

        bytes memory executeData = abi.encodeWithSelector(
            MinimalAccount.execute.selector,
            dest,
            value,
            functionData
        );

        PackedUserOperation memory userOp = generatedSingnatureOperation(
            executeData,
            helperConfig.getConfig(),
            minimalAccount
        );

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = userOp;

        address payable beneficiary = payable(helperConfig.getConfig().account);

        vm.startBroadcast();
        IEntryPoint(helperConfig.getConfig().entryPoint).handleOps(
            ops,
            beneficiary
        );
        vm.stopBroadcast();
    }

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
        PackedUserOperation memory unsignedUserOp = _generateUnsignedUserOp(
            callData,
            minimalAccount,
            nonce
        );

        bytes32 userOpHash = IEntryPoint(config.entryPoint).getUserOpHash(
            unsignedUserOp
        );

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

    function _generateUnsignedUserOp(
        bytes memory callData,
        address sender,
        uint256 nonce
    ) internal pure returns (PackedUserOperation memory) {
        uint256 verificationGasLimit = 200000;
        uint256 callGasLimit = 300000;
        uint256 maxFeePerGas = 10 gwei;
        uint256 maxPriorityFeePerGas = 10 gwei;

        return
            PackedUserOperation({
                sender: sender,
                nonce: nonce,
                initCode: hex"",
                callData: callData,
                accountGasLimits: bytes32(
                    (uint256(verificationGasLimit) << 128) | callGasLimit
                ),
                preVerificationGas: verificationGasLimit + 500000,
                gasFees: bytes32(
                    (uint256(maxPriorityFeePerGas) << 128) | maxFeePerGas
                ),
                paymasterAndData: hex"",
                signature: hex""
            });
    }
}
