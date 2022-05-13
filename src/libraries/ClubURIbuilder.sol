// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

/// @notice Builds Kali ClubSig tokenURI SVG
library ClubURIbuilder {
    function _buildTokenURI(
        string memory name,
        string memory symbol,
        address owner,
        uint256 loot
    ) internal pure returns (string memory) {
        string memory metaSVG = string(
            abi.encodePacked(
                '<text dominant-baseline="middle" text-anchor="middle" fill="white" x="50%" y="90px">',
                name,
                ' ',
                '(',
                symbol,
                ')',
                '</text>',
                '<text dominant-baseline="middle" text-anchor="middle" fill="white" x="50%" y="120px">',
                '0x',
                _addressToString(owner),
                '</text>',
                '<text dominant-baseline="middle" text-anchor="middle" fill="white" x="50%" y="150px">',
                _uintToString(loot),
                ' Loot Shares',
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

        return
            string(
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

    /// @dev converts an address to a string
    function _addressToString(address addr)
        private
        pure
        returns (string memory)
    {
        bytes memory s = new bytes(40);

        for (uint256 i; i < 20; ) {
            bytes1 b = bytes1(
                uint8(uint256(uint160(addr)) / (2**(8 * (19 - i))))
            );
            bytes1 hi = bytes1(uint8(b) / 16);
            bytes1 lo = bytes1(uint8(b) - 16 * uint8(hi));

            s[2 * i] = _char(hi);
            s[2 * i + 1] = _char(lo);
            // cannot realistically overflow
            unchecked {
                ++i;
            }
        }

        return string(s);
    }

    function _char(bytes1 b) private pure returns (bytes1 c) {
        if (uint8(b) < 10) return bytes1(uint8(b) + 0x30);
        else return bytes1(uint8(b) + 0x57);
    }

    /// @dev converts an unsigned integer to a string
    function _uintToString(uint256 n) internal pure returns (string memory str) {
        if (n == 0) return "0"; // otherwise it'd output an empty string for 0

        assembly {
            let k := 78 // start with the max length a uint256 string could be
            // we'll store our string at the first chunk of free memory
            str := mload(0x40)
            // the length of our string will start off at the max of 78
            mstore(str, k)
            // update the free memory pointer to prevent overriding our string
            // add 128 to the str pointer instead of 78 because we want to maintain
            // the Solidity convention of keeping the free memory pointer word aligned
            mstore(0x40, add(str, 128))
            // we'll populate the string from right to left
            for {} n {} {
                // the ASCII digit offset for '0' is 48
                let char := add(48, mod(n, 10))
                // write the current character into str
                mstore(add(str, k), char)
                k := sub(k, 1)
                n := div(n, 10)
            }
            // shift the pointer to the start of the string
            str := add(str, k)
            // set the length of the string to the correct value
            mstore(str, sub(78, k))
        }
    }

    /// @dev encodes some bytes to the base64 representation
    function _encode(bytes memory data) internal pure returns (string memory) {
        if (data.length == 0) return '';
        // load the table into memory
        string
            memory table = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
        // multiply by 4/3 rounded up
        uint256 encodedLen = 4 * ((data.length + 2) / 3);
        // add some extra buffer at the end required for the writing
        string memory result = new string(encodedLen + 32);

        assembly {
            // set the actual output length
            mstore(result, encodedLen)
            // prepare the lookup table
            let tablePtr := add(table, 1)
            // input ptr
            let dataPtr := data
            let endPtr := add(dataPtr, mload(data))
            // result ptr, jump over length
            let resultPtr := add(result, 32)
            // run over the input, 3 bytes at a time
            for {
            } lt(dataPtr, endPtr) {
            } {
                // read 3 bytes
                dataPtr := add(dataPtr, 3)
                let input := mload(dataPtr)
                // write 4 characters
                mstore8(
                    resultPtr,
                    mload(add(tablePtr, and(shr(18, input), 0x3F)))
                )
                resultPtr := add(resultPtr, 1)
                mstore8(
                    resultPtr,
                    mload(add(tablePtr, and(shr(12, input), 0x3F)))
                )
                resultPtr := add(resultPtr, 1)
                mstore8(
                    resultPtr,
                    mload(add(tablePtr, and(shr(6, input), 0x3F)))
                )
                resultPtr := add(resultPtr, 1)
                mstore8(resultPtr, mload(add(tablePtr, and(input, 0x3F))))
                resultPtr := add(resultPtr, 1)
            }
            // padding with '='
            switch mod(mload(data), 3)
            case 1 {
                mstore(sub(resultPtr, 2), shl(240, 0x3d3d))
            }
            case 2 {
                mstore(sub(resultPtr, 1), shl(248, 0x3d))
            }
        }

        return result;
    }
}
