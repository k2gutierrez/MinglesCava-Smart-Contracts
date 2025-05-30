// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {CavaNFT} from "../src/CavaNFT.sol";

contract DeployCava is Script {

    function run() external returns(CavaNFT){
        vm.startBroadcast();
        CavaNFT cava = new CavaNFT();
        vm.stopBroadcast();
        return cava;
    }
}