// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {ERC721A} from "../../lib/erc721a/contracts/ERC721A.sol";
import {Ownable} from "../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {Base64} from "../../lib/openzeppelin-contracts/contracts/utils/Base64.sol";
import {Strings} from "../../lib/openzeppelin-contracts/contracts/utils/Strings.sol";

contract CavaTequila is ERC721A, Ownable {
    using Strings for uint256;

    enum AgingState { Blanco, Reposado, Anejo }
    AgingState public currentState;
    uint256 public lastStateChange;
    uint256 public constant MAX_SUPPLY = 5555;
    uint256 private constant GRID_DIM = 25;
    uint256 private constant CELL_SIZE = 20;
    uint256 private constant CANVAS_SIZE = GRID_DIM * CELL_SIZE;
    uint256 private constant BLOB_COUNT = 50;

    constructor() ERC721A("CAVA", "CAVA") Ownable(msg.sender) {
        currentState = AgingState.Blanco;
        lastStateChange = block.timestamp;
    }

    // Add missing _intToString function
    function _intToString(int256 value) internal pure returns (string memory) {
        return value < 0 
            ? string(abi.encodePacked("-", Strings.toString(uint256(-value))))
            : Strings.toString(uint256(value));
    }

    // Add missing _generateBlobs function
    function _generateBlobs(uint256 tokenId) internal view returns (string memory) {
        bytes memory blobs;
        for (uint256 i = 0; i < BLOB_COUNT; i++) {
            uint256 seed = uint256(keccak256(abi.encodePacked(block.prevrandao, i, tokenId)));
            blobs = abi.encodePacked(blobs, _buildBlob(seed));
        }
        return string(blobs);
    }

    function _buildBlob(uint256 seed) internal view returns (bytes memory) {
        uint256 pos = (seed % GRID_DIM) * CELL_SIZE;
        uint256 size = 8 + (seed >> 8) % 12;
        
        return abi.encodePacked(
            '<rect x="', (pos + (seed >> 16) % 4).toString(),
            '" y="', (pos + (seed >> 24) % 4).toString(),
            '" width="', size.toString(),
            '" height="', size.toString(),
            '" fill="', _getColor((seed >> 32) % 8, currentState), '">',
            '<animateTransform attributeName="transform" type="translate" ',
            'values="0 0;', _intToString(int256((seed >> 40) % 41) - 20), 
            ' ', _intToString(int256((seed >> 48) % 41) - 20), 
            ';0 0" dur="', (3 + (seed >> 56) % 3).toString(), 
            's" repeatCount="indefinite"/></rect>'
        );
    }

    function _getColor(uint256 idx, AgingState s) internal pure returns (string memory) {
        string[5] memory pal;
        if (s == AgingState.Blanco) pal = ["#F0F8FF","#B0E0E6","#87CEEB","#ADD8E6","#D4F2FF"];
        else if (s == AgingState.Reposado) pal = ["#FFD700","#FFA500","#FF8C00","#FFB90F","#EEB422"];
        else pal = ["#8B0000","#A52A2A","#B22222","#8B4513","#CD853F"];
        return pal[idx % 5];
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "Nonexistent token");
        
        bytes memory svg = abi.encodePacked(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ', CANVAS_SIZE.toString(), ' ', CANVAS_SIZE.toString(), '">',
            '<rect width="100%" height="100%" fill="', 
            currentState == AgingState.Blanco ? "#F0F8AA" : 
            currentState == AgingState.Reposado ? "#8B4513" : "#4B0404", '"/>',
            _generateBlobs(tokenId),
            '</svg>'
        );

        return string(abi.encodePacked(
            "data:application/json;base64,",
            Base64.encode(abi.encodePacked(
                '{"name":"CAVA #', tokenId.toString(),
                '","image":"data:image/svg+xml;base64,',
                Base64.encode(svg),
                '"}'
            ))
        ));
    }

    function advanceState() external onlyOwner {
        currentState = AgingState((uint256(currentState) + 1) % 3);
        lastStateChange = block.timestamp;
    }

    function mint(uint256 quantity) external {
        require(totalSupply() + quantity <= MAX_SUPPLY, "Max supply exceeded");
        _safeMint(msg.sender, quantity);
    }
}