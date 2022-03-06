// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity >=0.8.4;

/// @notice ERC-1271 interface
interface IERC1271 {
    function isValidSignature(bytes32 hash, bytes calldata signature) external view returns (bytes4);
}
