//SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {
    EntryPoint
} from "lib/account-abstraction/contracts/core/EntryPoint.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        address entryPoint;
        address account;
    }

    error HelperConfig__InvalidChainID();

    uint256 public constant ETH_SEPOLLIA_CHAIN_ID = 11155111;
    uint256 public constant ZKSYNC_SEPOLLIA_CHAIN_ID = 300;
    uint256 public constant LOCAL_CHAIN_ID = 31337;

    address constant ANVIL_LOCAL_ADDRESS =
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    address public constant BURNER_WALLET =
        0x5f265547093b1c70011b5036C77A5378a7D9c8eA;

    NetworkConfig public localNetworkConfig;
    mapping(uint256 chainId => NetworkConfig) public networkConfigs;

    constructor() {
        networkConfigs[ETH_SEPOLLIA_CHAIN_ID] = getEthSepiliaConfigs();
        networkConfigs[ZKSYNC_SEPOLLIA_CHAIN_ID] = getZkSyncSepoliaConfigs();
    }

    function getEthSepiliaConfigs() public pure returns (NetworkConfig memory) {
        return
            NetworkConfig({
                entryPoint: 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789,
                account: BURNER_WALLET
            });
    }

    function getZkSyncSepoliaConfigs()
        public
        pure
        returns (NetworkConfig memory)
    {
        return NetworkConfig({entryPoint: address(0), account: BURNER_WALLET});
    }

    function getOrCreateLocalAnvilEthConfigs()
        public
        returns (NetworkConfig memory)
    {
        if (localNetworkConfig.account != address(0)) {
            return localNetworkConfig;
        }

        NetworkConfig memory sepoliaConfig = getEthSepiliaConfigs();

        console.log("Deploying on Anvil");
        vm.startBroadcast(ANVIL_LOCAL_ADDRESS);
        EntryPoint entrypoint = new EntryPoint();
        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({
            entryPoint: address(entrypoint),
            account: ANVIL_LOCAL_ADDRESS
        });
        return localNetworkConfig;
    }

    function getConfigByChainId(
        uint256 chainId
    ) public returns (NetworkConfig memory) {
        if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateLocalAnvilEthConfigs();
        }
        if (networkConfigs[chainId].account != address(0)) {
            return networkConfigs[chainId];
        }
        revert HelperConfig__InvalidChainID();
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }
}
