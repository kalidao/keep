// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

/// @notice Provides functions for building tokenURI SVG
/// @author Modified from Brecht Devos (https://github.com/Brechtpd/base64/blob/main/base64.sol)
/// License-Identifier: MIT
library URIbuilder {
    bytes internal constant TABLE = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    
    function _buildTokenURI(
        address owner, 
        uint256 loot,
        string memory name
    ) internal pure returns (string memory) {
        string memory metaSVG = string(
            abi.encodePacked(
                '<text dominant-baseline="middle" text-anchor="middle" fill="white" x="50%" y="90px">',
                '0x',
                _addressToString(owner),
                '</text>',
                '<text dominant-baseline="middle" text-anchor="middle" fill="white" x="100%" y="180px">',
                _uintToString(loot),
                ' Loot',
                '</text>'
            )
        );

        bytes memory svg = abi.encodePacked(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400" preserveAspectRatio="xMidYMid meet" style="font:14px serif"><rect width="400" height="400" fill="black" />',
            metaSVG,
            '</svg>'
        );

        bytes memory image = abi.encodePacked(
            'data:image/svg+xml;base64,',
            _encode(bytes(svg))
        );

        return string(
            abi.encodePacked(
                'data:application/json;base64,',
                _encode(
                    bytes(
                        abi.encodePacked(
                            '{"name":"',
                            name,
                            '", "image":"',
                            image,
                            '", "description": "The holder of this NFT is a club key signer."}'
                        )
                    )
                )
            )
        );
    }

    function _addressToString(address addr) internal pure returns (string memory) {
        bytes memory s = new bytes(40);

        for (uint256 i; i < 20;) {
            bytes1 b = bytes1(uint8(uint256(uint160(addr)) / (2**(8*(19 - i)))));
            bytes1 hi = bytes1(uint8(b) / 16);
            bytes1 lo = bytes1(uint8(b) - 16 * uint8(hi));

            s[2*i] = _char(hi);
            s[2*i+1] = _char(lo);
            // cannot realistically overflow on human timescales
            unchecked { 
                ++i; 
            }
        }

        return string(s);
    }

    function _char(bytes1 b) internal pure returns (bytes1 c) {
        if (uint8(b) < 10) return bytes1(uint8(b) + 0x30);
        else return bytes1(uint8(b) + 0x57);
    }

    function _uintToString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return '0';

        uint256 temp = value;
        uint256 digits;

        while (temp != 0) {
            // cannot realistically overflow on human timescales
            unchecked {
                ++digits;
            }

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

    /// @dev encodes some bytes to the base64 representation
    function _encode(bytes memory data) internal pure returns (string memory) {
        uint256 len = data.length;
        
        if (len == 0) return '';

        // multiply by 4/3 rounded up
        uint256 encodedLen = 4 * ((len + 2) / 3);

        // add some extra buffer at the end
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
                out := add(out, and(mload(add(tablePtr, and(shr(12, input), 0x3F))), 0xFF))
                out := shl(8, out)
                out := add(out, and(mload(add(tablePtr, and(shr(6, input), 0x3F))), 0xFF))
                out := shl(8, out)
                out := add(out, and(mload(add(tablePtr, and(input, 0x3F))), 0xFF))
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
