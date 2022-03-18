// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

/// @notice Minimal ERC-20 interface with Kali ClubSig extensions
interface IClubLoot { 
    function balanceOf(address account) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function mint(address to, uint256 amount) external;
    function govBurn(address from, uint256 amount) external;
    function setPause(bool paused) external;
}
