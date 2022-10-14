// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Interface for Kali DAO extensions.
abstract contract KaliExtension {
    function setExtension(bytes calldata extensionData) public virtual;
}
