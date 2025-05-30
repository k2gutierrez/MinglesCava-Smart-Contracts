// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {CavaStaking} from "../src/CavaStaking.sol";

contract DeployCavaStaking is Script {

    address immutable i_nftAddress;
    address immutable i_cavaAddress;

    constructor(address _nftAddress, address __cavaAddress){
        i_nftAddress = _nftAddress;
        i_cavaAddress = __cavaAddress;
    }

    function run() external returns(CavaStaking){
        vm.startBroadcast();
        CavaStaking staking = new CavaStaking(i_nftAddress, i_cavaAddress);
        vm.stopBroadcast();
        return staking;
    }
}