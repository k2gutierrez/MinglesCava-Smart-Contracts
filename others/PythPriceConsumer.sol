// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IPyth} from "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import {PythStructs} from "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";

contract PythPriceConsumer {

    IPyth public pyth;
    bytes32 public priceFeedId;
    uint256 public lastPrice;
    uint256 public lastUpdated;

    constructor(address _pythContract, bytes32 _priceFeedId) {
        pyth = IPyth(_pythContract);
        priceFeedId = _priceFeedId;
    }

    function updatePrice(bytes[] calldata priceUpdateData) external payable {
        pyth.updatePriceFeeds{value: msg.value}(priceUpdateData);
        PythStructs.Price memory price = pyth.getPriceUnsafe(priceFeedId);
        
        // Convert exponent to positive integer safely
        int256 calculatedExponent = int256(18) + int256(price.expo);
        require(calculatedExponent >= 0, "Negative exponent not supported");
        uint256 exponent = uint256(calculatedExponent);

        lastPrice = uint256(uint64(price.price)) * (10 ** exponent);
        lastUpdated = block.timestamp;
    }

    function usdToApe(uint256 usdAmount) public view returns (uint256) {
        require(lastPrice > 0, "Price not initialized");
        require(block.timestamp - lastUpdated < 300, "Price too stale");
        return (usdAmount * 1e18) / lastPrice;
    }

    function getMintCost(uint256 quantity) public view returns (uint256) {
        return usdToApe(quantity * 1e18); // $6 in USD with 18 decimals
    }
}

contract ApeMinter {
    PythPriceConsumer public priceOracle;
    
    constructor(address _priceConsumer) {
        priceOracle = PythPriceConsumer(_priceConsumer);
    }

    function mint(uint256 quantity) external payable {
        uint256 requiredApe = priceOracle.getMintCost(quantity);
        require(msg.value >= requiredApe, "Insufficient APE");
        
        // Minting logic here
        _mint(msg.sender);
        
        // Refund excess
        if(msg.value > requiredApe) {
            payable(msg.sender).transfer(msg.value - requiredApe);
        }
    }

    function _mint(address to) internal {
        // Your minting implementation
    }

    // Important: Allow contract to receive update fees
    receive() external payable {}
}