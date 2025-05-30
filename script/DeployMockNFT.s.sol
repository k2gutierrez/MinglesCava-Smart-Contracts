// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {NFT} from "../src/MockNFT.sol";

contract DeployMockNFT is Script {

    function run() external returns(NFT){
        vm.startBroadcast();
        NFT mockNFT = new NFT();
        vm.stopBroadcast();
        return mockNFT;
    }
}