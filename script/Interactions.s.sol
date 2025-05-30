// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";
import {CavaNFT} from "../src/CavaNFT.sol";

contract fundReposado is Script {

    uint256 constant SEND_VALUE = 0.01 ether;

    function sendReposadoMoney(address mostRecentlyDeployed) public {
        vm.startBroadcast();
        CavaNFT(payable(mostRecentlyDeployed)).transferReposadoMoneyToContract{value: SEND_VALUE}();
        vm.stopBroadcast();
        console.log("Funded from reposado money with %s", SEND_VALUE);
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("CavaNFT", block.chainid);
        sendReposadoMoney(mostRecentlyDeployed);
    }
}

contract fundAnejo is Script {

    uint256 constant SEND_VALUE = 0.02 ether;

    function sendAnejoMoney(address mostRecentlyDeployed) public {
        vm.startBroadcast();
        CavaNFT(payable(mostRecentlyDeployed)).transferAnejoMoneyToContract{value: SEND_VALUE}();
        vm.stopBroadcast();
        console.log("Funded from Anejo money with %s", SEND_VALUE);
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("CavaNFT", block.chainid);
        sendAnejoMoney(mostRecentlyDeployed);
    }
}

contract fundBottle is Script {

    uint256 constant SEND_VALUE = 0.03 ether;

    function sendBottleMoney(address mostRecentlyDeployed) public {
        vm.startBroadcast();
        CavaNFT(payable(mostRecentlyDeployed)).transferMoneyToContract{value: SEND_VALUE}();
        vm.stopBroadcast();
        console.log("Funded from bottles money with %s", SEND_VALUE);
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("CavaNFT", block.chainid);
        sendBottleMoney(mostRecentlyDeployed);
    }
}

contract WithdrawReposadoOwner is Script {
    function withdrawReposadoOwner(address mostRecentlyDeployed) public {
        vm.startBroadcast();
        CavaNFT(payable(mostRecentlyDeployed)).withdrawReposado();
        vm.stopBroadcast();
        console.log("Withdraw reposado balance!");
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("CavaNFT", block.chainid);
        
        withdrawReposadoOwner(mostRecentlyDeployed);
        
    }
}

contract WithdrawAnejoOwner is Script {
    function withdrawAnejoOwner(address mostRecentlyDeployed) public {
        vm.startBroadcast();
        CavaNFT(payable(mostRecentlyDeployed)).withdrawAnejo();
        vm.stopBroadcast();
        console.log("Withdraw Anejo balance!");
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("CavaNFT", block.chainid);
        
        withdrawAnejoOwner(mostRecentlyDeployed);
        
    }
}

contract WithdrawBottlesOwner is Script {
    function withdrawBottleOwner(address mostRecentlyDeployed) public {
        vm.startBroadcast();
        CavaNFT(payable(mostRecentlyDeployed)).withdrawABottles();
        vm.stopBroadcast();
        console.log("Withdraw bottles balance!");
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("CavaNFT", block.chainid);
        
        withdrawBottleOwner(mostRecentlyDeployed);
        
    }
}