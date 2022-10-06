// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Keep URI fetcher interface.
abstract contract URIFetcher {
    function fetchURI(address account, uint256 id)
        public
        view
        virtual
        returns (string memory);
}
