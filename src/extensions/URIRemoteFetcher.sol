// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Owned} from "./utils/Owned.sol";

/// @notice Remote metadata fetcher for ERC1155 URI.
contract URIRemoteFetcher is Owned {
    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event URISet(
        address indexed user, 
        address indexed origin, 
        uint256 indexed id, 
        string uri
    );

    event AlphaURISet(address indexed user, string indexed alphaURI);

    event BaseURISet(address indexed user, string indexed baseURI);

    /// -----------------------------------------------------------------------
    /// URI Storage
    /// -----------------------------------------------------------------------

    string public alphaURI;

    string public baseURI;

    mapping(address => mapping(uint256 => string)) public uris;

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor(address _owner) payable Owned(_owner) {}

    /// -----------------------------------------------------------------------
    /// URI Logic
    /// -----------------------------------------------------------------------
    
    function fetchURI(address origin, uint256 id) public view virtual returns (string memory) {
        string memory uri = uris[origin][id];
        string memory alpha = alphaURI;
        string memory base = baseURI;

        if (bytes(uri).length != 0) return uri;
        else if (bytes(alpha).length != 0) return alpha;
        else return bytes(base).length != 0 ? string(abi.encodePacked(base, _toString(id))) : "";
    }

    function setURI(
        address origin, 
        uint256 id, 
        string calldata uri
    ) public payable onlyOwner virtual {
        uris[origin][id] = uri;

        emit URISet(msg.sender, origin, id, uri);
    }

    function setAlphaURI(string calldata _alphaURI) public payable onlyOwner virtual {
        alphaURI = _alphaURI;

        emit AlphaURISet(msg.sender, _alphaURI);
    }

    function setBaseURI(string calldata _baseURI) public payable onlyOwner virtual {
        baseURI = _baseURI;

        emit BaseURISet(msg.sender, _baseURI);
    }

    /// @dev Returns the base 10 decimal representation of `value`.
    function _toString(uint256 value) internal pure virtual returns (string memory str) {
        assembly {
            // The maximum value of a uint256 contains 78 digits (1 byte per digit), but
            // we allocate 0xa0 bytes to keep the free memory pointer 32-byte word aligned.
            // We will need 1 word for the trailing zeros padding, 1 word for the length,
            // and 3 words for a maximum of 78 digits. Total: 5 * 0x20 = 0xa0.
            let m := add(mload(0x40), 0xa0)
            // Update the free memory pointer to allocate.
            mstore(0x40, m)
            // Assign the `str` to the end.
            str := sub(m, 0x20)
            // Zeroize the slot after the string.
            mstore(str, 0)

            // Cache the end of the memory to calculate the length later.
            let end := str

            // We write the string from rightmost digit to leftmost digit.
            // The following is essentially a do-while loop that also handles the zero case.
            // prettier-ignore
            for { let temp := value } 1 {} {
                str := sub(str, 1)
                // Write the character to the pointer.
                // The ASCII index of the '0' character is 48.
                mstore8(str, add(48, mod(temp, 10)))
                // Keep dividing `temp` until zero.
                temp := div(temp, 10)
                // prettier-ignore
                if iszero(temp) { break }
            }

            let length := sub(end, str)
            // Move the pointer 32 bytes leftwards to make room for the length.
            str := sub(str, 0x20)
            // Store the length.
            mstore(str, length)
        }
    }    
}
