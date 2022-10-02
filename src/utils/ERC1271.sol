// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice ERC1271 interface (https://eips.ethereum.org/EIPS/eip-1271).
abstract contract ERC1271 {
    function isValidSignature(bytes32 hash, bytes calldata signature)
        public
        view
        virtual
        returns (bytes4);
}
