// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

/// @notice Builds Kali ClubSig tokenURI SVG
library ClubURIbuilder {
    string private constant TABLE =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

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
                " ",
                "(",
                symbol,
                ")",
                "</text>",
                '<text dominant-baseline="middle" text-anchor="middle" fill="white" x="50%" y="120px">',
                "0x",
                _addressToString(owner),
                "</text>",
                '<text dominant-baseline="middle" text-anchor="middle" fill="white" x="50%" y="150px">',
                _uintToString(loot),
                " Loot Shares",
                "</text>"
            )
        );

        bytes memory svg = abi.encodePacked(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400" preserveAspectRatio="xMidYMid meet" style="font:14px serif"><rect width="400" height="400" fill="black" />',
            metaSVG,
            "</svg>"
        );

        bytes memory image = abi.encodePacked(
            "data:image/svg+xml;base64,",
            _encode(bytes(svg))
        );

        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
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
            // cannot realistically overflow on human timescales
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
    function _uintToString(uint256 value)
        private
        pure
        returns (string memory)
    {
        if (value == 0) {
            return '0';
        }
        uint256 j = value;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint256 k = len;
        while (value != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(value - (value / 10) * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            value /= 10;
        }
        return string(bstr);
    }

    /// @dev encodes some bytes to the base64 representation
    function _encode(bytes memory data) private pure returns (string memory) {
        // inspired by Brecht Devos (Brechtpd) implementation - MIT licence
        // https://github.com/Brechtpd/base64/blob/e78d9fd951e7b0977ddca77d92dc85183770daf4/base64.sol
        if (data.length == 0) return "";
        // loads the table into memory
        string memory table = TABLE;
        // encoding takes 3 bytes chunks of binary data from `bytes` data parameter
        // and split into 4 numbers of 6 bits.
        // the final Base64 length should be `bytes` data length multiplied by 4/3 rounded up
        // - `data.length + 2`  -> round up
        // - `/ 3`              -> number of 3-bytes chunks
        // - `4 *`              -> 4 characters for each chunk
        string memory result = new string(4 * ((data.length + 2) / 3));

        assembly {
            // prepare the lookup table (skip the first "length" byte)
            let tablePtr := add(table, 1)
            // prepare result pointer, jump over length
            let resultPtr := add(result, 32)
            // run over the input, 3 bytes at a time
            for {
                let dataPtr := data
                let endPtr := add(data, mload(data))
            } lt(dataPtr, endPtr) {
            } {
                // advance 3 bytes
                dataPtr := add(dataPtr, 3)
                let input := mload(dataPtr)
                // to write each character, shift the 3 bytes (18 bits) chunk
                // 4 times in blocks of 6 bits for each character (18, 12, 6, 0)
                // and apply logical AND with 0x3F which is the number of
                // the previous character in the ASCII table prior to the Base64 Table
                // the result is then added to the table to get the character to write,
                // and finally write it in the result pointer but with a left shift
                // of 256 (1 byte) - 8 (1 ASCII char) = 248 bits
                mstore8(resultPtr, mload(add(tablePtr, and(shr(18, input), 0x3F))))
                resultPtr := add(resultPtr, 1) // Advance

                mstore8(resultPtr, mload(add(tablePtr, and(shr(12, input), 0x3F))))
                resultPtr := add(resultPtr, 1) // Advance

                mstore8(resultPtr, mload(add(tablePtr, and(shr(6, input), 0x3F))))
                resultPtr := add(resultPtr, 1) // Advance

                mstore8(resultPtr, mload(add(tablePtr, and(input, 0x3F))))
                resultPtr := add(resultPtr, 1) // Advance
            }
            // when data `bytes` is not exactly 3 bytes long
            // it is padded with `=` characters at the end
            switch mod(mload(data), 3)
            case 1 {
                mstore8(sub(resultPtr, 1), 0x3d)
                mstore8(sub(resultPtr, 2), 0x3d)
            }
            case 2 {
                mstore8(sub(resultPtr, 1), 0x3d)
            }
        }

        return result;
    }
}
