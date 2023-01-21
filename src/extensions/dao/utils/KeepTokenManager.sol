// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Contract helper for Keep token management.
abstract contract KeepTokenManager {
    function balanceOf(
        address account,
        uint256 id
    ) public view virtual returns (uint256);

    function totalSupply(uint256 id) public view virtual returns (uint256);

    function transferable(uint256 id) public view virtual returns (bool);

    function getPriorVotes(
        address account,
        uint256 id,
        uint256 timestamp
    ) public view virtual returns (uint256);

    function mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) public payable virtual;

    function burn(
        address from,
        uint256 id,
        uint256 amount
    ) public payable virtual;

    function setTransferability(uint256 id, bool on) public payable virtual;
}
