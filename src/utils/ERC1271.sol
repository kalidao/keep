// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice ERC-1271 interface.
/// @dev https://eips.ethereum.org/EIPS/eip-1271
abstract contract ERC1271 {
    function isValidSignature(bytes32 hash, bytes calldata signature)
        external
        view
        virtual
        returns (bytes4);
}
