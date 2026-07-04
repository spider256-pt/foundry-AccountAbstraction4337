//SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {MinimalAccount} from "../src/ethereum/MinimalAccount.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployMinimal is Script {
    function deployrMinimalAccount()
        public
        returns (HelperConfig helperConfigInstance, MinimalAccount minimalAccountContract)
    {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        vm.startBroadcast(config.account);
        MinimalAccount minimalAcc = new MinimalAccount(config.entryPoint);
        minimalAcc.transferOwnership(config.account);
        vm.stopBroadcast();

        return (helperConfig, minimalAcc);
    }

    function run() external returns (HelperConfig, MinimalAccount) {
        return deployrMinimalAccount();
    }
}
