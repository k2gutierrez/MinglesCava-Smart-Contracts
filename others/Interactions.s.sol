// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {TequilaNFT} from "../src/Cava.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract MintBasicNFT is Script {

    address private constant MAIN = 0xca067E20db2cDEF80D1c7130e5B71C42c0305529;
    
    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("TequilaNFT", block.chainid);
        mintNftOnContract(mostRecentlyDeployed);
    }

    function mintNftOnContract(address contractAddress) public {
        uint256 qty = 2;
        vm.startBroadcast();
        TequilaNFT(contractAddress).mint(qty);
        vm.stopBroadcast();
    }

}

contract CheckURI is Script {

    address private constant MAIN = 0xca067E20db2cDEF80D1c7130e5B71C42c0305529;
    
    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("TequilaNFT", block.chainid);
        checkUri(mostRecentlyDeployed);
    }

    function checkUri(address contractAddress) public {
        uint256 id = 1;
        vm.startBroadcast();
        TequilaNFT(contractAddress).tokenURI(id);
        vm.stopBroadcast();
    }

}
