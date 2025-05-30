// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721A} from "../../lib/erc721a/contracts/ERC721A.sol";
import {Ownable} from "../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {Base64} from "../../lib/openzeppelin-contracts/contracts/utils/Base64.sol";

contract TequilaNFT is ERC721A, Ownable {
    enum TequilaState { Blanco, Reposado, Anejo }
    TequilaState private s_currentState;
    uint256 public s_startingTime;

    constructor() ERC721A("TequilaNFT", "TEQ") Ownable(msg.sender) {
        s_currentState = TequilaState.Blanco;
        s_startingTime = block.timestamp;
    }

    // Función para cambiar el estado (solo owner)
    function advanceState() external onlyOwner {
        if (s_currentState == TequilaState.Blanco) {
            s_currentState = TequilaState.Reposado;
        } else if (s_currentState == TequilaState.Reposado) {
            s_currentState = TequilaState.Anejo;
        }
        s_startingTime = block.timestamp;
    }

    // Función de mint público básico para demostración
    function mint(uint256 quantity) external {
        _mint(msg.sender, quantity);
    }

    // Generación del arte on-chain
    function generateSVG() internal view returns (string memory) {
        string memory color;
        if (s_currentState == TequilaState.Blanco) {
            color = "#FFFFFF";
        } else if (s_currentState == TequilaState.Reposado) {
            color = "#FFFF00";
        } else {
            color = "#8B0000";
        }

        return string(abi.encodePacked(
            '<svg viewBox="0 0 32 32" xmlns="http://www.w3.org/2000/svg" style="background:#000000">',
            '<rect x="0" y="8" width="32" height="16" fill="',color,'" opacity="0.8">',
            '<animate attributeName="x" values="0; 16; 0" dur="3s" repeatCount="indefinite"/>',
            '</rect>',
            '<rect x="-16" y="8" width="32" height="16" fill="',color,'" opacity="0.8">',
            '<animate attributeName="x" values="-16; 0; -16" dur="3s" repeatCount="indefinite"/>',
            '</rect>',
            '</svg>'
        ));
    }

    // Generación de metadata on-chain
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "Token no existe");
        
        string memory svg = generateSVG();
        string memory json = Base64.encode(bytes(abi.encodePacked(
            '{"name": "Tequila NFT #', toString(tokenId), '",',
            '"description": "Tequila Collection con cambio de estado on-chain",',
            '"attributes": [{"trait_type": "Estado", "value": "', stateToString(), '"}],',
            '"image": "data:image/svg+xml;base64,', Base64.encode(bytes(svg)), '"}'
        )));
        
        return string(abi.encodePacked("data:application/json;base64,", json));
    }

    // Helper para convertir estado a string
    function stateToString() internal view returns (string memory) {
        if (s_currentState == TequilaState.Blanco) return "Blanco";
        if (s_currentState == TequilaState.Reposado) return "Reposado";
        return "Anejo";
    }

    // Helper para convertir uint a string
    function toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}

// Helper para codificación Base64
/**
library Base64 {
    bytes internal constant TABLE = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

    function encode(bytes memory data) internal pure returns (string memory) {
        uint256 len = data.length;
        if (len == 0) return "";

        uint256 encodedLen = 4 * ((len + 2) / 3);
        bytes memory result = new bytes(encodedLen + 32);

        bytes memory table = TABLE;

        assembly {
            let tablePtr := add(table, 1)
            let resultPtr := add(result, 32)

            for {
                let i := 0
            } lt(i, len) {

            } {
                i := add(i, 3)
                let input := and(mload(add(data, i)), 0xffffff)

                let out := mload(add(tablePtr, and(shr(18, input), 0x3F)))
                out := shl(8, out)
                out := add(out, mload(add(tablePtr, and(shr(12, input), 0x3F))))
                out := shl(8, out)
                out := add(out, mload(add(tablePtr, and(shr(6, input), 0x3F))))
                out := shl(8, out)
                out := add(out, mload(add(tablePtr, and(input, 0x3F))))
                out := shl(224, out)

                mstore(resultPtr, out)
                resultPtr := add(resultPtr, 4)
            }

            switch mod(len, 3)
            case 1 {
                mstore(sub(resultPtr, 2), shl(240, 0x3d3d))
            }
            case 2 {
                mstore(sub(resultPtr, 1), shl(248, 0x3d))
            }

            mstore(result, encodedLen)
        }

        return string(result);
    }
}
 */