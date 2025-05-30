// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {NFT} from "../src/nft.sol";

contract DeployMingles is Script {

    string constant NAME = "Mingles";
    string constant SYMBOL = "Mgls";
    string constant URI = "ipfs://QmcoeRsFYeHzPD9Gx84aKD3tjLUKjvPEMSmoPs2GQmHR1t/";

    function run() external returns(NFT){
        vm.startBroadcast();
        NFT basicNFT = new NFT(NAME, SYMBOL, URI);
        vm.stopBroadcast();
        return basicNFT;
    }
}

contract DeployGS is Script {

    string constant NAME = "GSAPEMOCK";
    string constant SYMBOL = "GSAM";
    string constant URI = "https://bafybeigivlw2x5hefqfurmfzp5v365cznsnz65oowqaewmxvo53xy3p7u4.ipfs.w3s.link/";

    function run() external returns(NFT){
        vm.startBroadcast();
        NFT basicNFT = new NFT(NAME, SYMBOL, URI);
        vm.stopBroadcast();
        return basicNFT;
    }
}