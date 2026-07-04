//SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {MinimalAccount} from "../../src/ethereum/MinimalAccount.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DeployMinimal} from "../../script/DeployMinimal.s.sol";
import {
    SendPackedOperation,
    PackedUserOperation
} from "../../script/SendPackedOperation.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {
    EntryPoint
} from "lib/account-abstraction/contracts/core/EntryPoint.sol";
import {
    IEntryPoint
} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {
    MessageHashUtils
} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

using MessageHashUtils for bytes32;

contract MinimalAccountTest is Test {
    HelperConfig helperConfig;
    SendPackedOperation sendPackedUserOpScript;
    HelperConfig.NetworkConfig activeNetworkConfig;
    MinimalAccount minimalAccount;
    address owner;
    ERC20Mock usdc;
    EntryPoint mockEntryPoint;
    uint256 constant AMOUNT = 1e18;

    address randomUser = makeAddr("randomUser");

    function setUp() public {
        owner = address(0x5f265547093b1c70011b5036C77A5378a7D9c8eA);
        minimalAccount = new MinimalAccount(owner);
        mockEntryPoint = new EntryPoint();

        sendPackedUserOpScript = new SendPackedOperation();
        helperConfig = new HelperConfig();
        activeNetworkConfig = helperConfig.getOrCreateLocalAnvilEthConfigs();

        DeployMinimal deployMinimal = new DeployMinimal();
        (helperConfig, minimalAccount) = deployMinimal.deployrMinimalAccount();
        usdc = new ERC20Mock();

        sendPackedUserOpScript.setHelperConfig(helperConfig);
    }

    function testEntryPointCanExecuteCommands() public {
        //Arrange
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);

        address dest = address(usdc);
        uint256 value = 0;

        bytes memory functionalData = abi.encodeWithSelector(
            usdc.mint.selector,
            address(minimalAccount),
            AMOUNT
        );

        bytes memory executeCallData = abi.encodeWithSelector(
            minimalAccount.execute.selector,
            dest,
            value,
            functionalData
        );

        PackedUserOperation memory packedUserOp = sendPackedUserOpScript
            .generatedSingnatureOperation(
                executeCallData,
                helperConfig.getConfig(),
                address(minimalAccount)
            );

        vm.deal(address(minimalAccount), 1e18);

        //Act
        vm.prank(randomUser);
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = packedUserOp;

        IEntryPoint(helperConfig.getConfig().entryPoint).handleOps(
            ops,
            payable(randomUser)
        );
        //Assert
        assertEq(usdc.balanceOf(address(minimalAccount)), AMOUNT);
    }

    function testValidationOfUserOps() public {
        //Arrange

        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functiondata = abi.encodeWithSelector(
            usdc.mint.selector,
            address(minimalAccount),
            AMOUNT
        );

        bytes memory executeCallData = abi.encodeWithSelector(
            minimalAccount.execute.selector,
            dest,
            value,
            functiondata
        );

        PackedUserOperation memory packedUserOp = sendPackedUserOpScript
            .generatedSingnatureOperation(
                executeCallData,
                helperConfig.getConfig(),
                address(minimalAccount)
            );

        bytes32 userOpHash = IEntryPoint(helperConfig.getConfig().entryPoint)
            .getUserOpHash(packedUserOp);

        uint256 validateUserFunds = 1e18;
        //Act
        vm.prank(address(helperConfig.getConfig().entryPoint));
        uint256 validationData = minimalAccount.validateUserOp(
            packedUserOp,
            userOpHash,
            validateUserFunds
        );
        //Assert

        assertEq(validationData, 0, "Validation Falied");
    }

    function testUserSignedOp() public {
        //Arrange
        uint256 AMOUNT = 100e6;
        bytes memory functionDataForUSDCMint = abi.encodeWithSelector(
            usdc.mint.selector,
            address(minimalAccount),
            AMOUNT
        );

        bytes memory executeCallData = abi.encodeWithSelector(
            minimalAccount.execute.selector,
            address(usdc),
            0,
            functionDataForUSDCMint
        );

        PackedUserOperation memory packedUserOp = sendPackedUserOpScript
            .generatedSingnatureOperation(
                executeCallData,
                activeNetworkConfig,
                address(minimalAccount)
            );

        bytes32 userOperationHash = IEntryPoint(activeNetworkConfig.entryPoint)
            .getUserOpHash(packedUserOp);
        //Act

        address actualSigner = ECDSA.recover(
            userOperationHash.toEthSignedMessageHash(),
            packedUserOp.signature
        );

        console.log("Owner Address", minimalAccount.owner());
        console.log("Actual signer: ", actualSigner);
        console.log("Address of this contract: ", address(this));
        //Assert
        assertEq(
            actualSigner,
            minimalAccount.owner(),
            "Signer recovery Failed"
        );
    }

    function testOwnerCanExecuteCommands() public {
        //Arrange
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;

        bytes memory functionData = abi.encodeWithSelector(
            ERC20Mock.mint.selector,
            address(minimalAccount),
            AMOUNT
        );
        //Act
        vm.prank(minimalAccount.owner());
        minimalAccount.execute(dest, value, functionData);
        //Assert
        assertEq(
            usdc.balanceOf(address(minimalAccount)),
            AMOUNT,
            "MinimalAccount should have minited USDC"
        );
    }

    function testNonOwnerCannotExecuteCommands() public {
        //Arrange
        address dest = address(usdc);
        uint256 value = 0;

        bytes memory functionData = abi.encodeWithSelector(
            ERC20Mock.mint.selector,
            address(minimalAccount),
            AMOUNT
        );
        //Act && Assert
        vm.prank(randomUser);
        vm.expectRevert(
            MinimalAccount.MinimalAccount__NotFromEntryPointOrOwner.selector
        );
        minimalAccount.execute(dest, value, functionData);
    }
}
