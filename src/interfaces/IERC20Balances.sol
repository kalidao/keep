// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

/// @notice Minimal ERC-20 interface for tracking balances
interface IERC20Balances { 
    function balanceOf(address account) external view returns (uint256);

    function totalSupply() external view returns (uint256);
}
