// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Minimal ERC-20 interface for tracking balances.
/// @dev Modified from EIP-20 (https://eips.ethereum.org/EIPS/eip-20)
interface IERC20Balances {
    function balanceOf(address account) external view returns (uint256);

    function totalSupply() external view returns (uint256);
}
