// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Contract helper for Keep token balances.
abstract contract KeepTokenBalances {
    function balanceOf(address account, uint256 id)
        public
        view
        virtual
        returns (uint256);

    function totalSupply(uint256 id) public view virtual returns (uint256);

    function transferable(uint256 id) public view virtual returns (bool);

    function getPriorVotes(
        address account,
        uint256 id,
        uint256 timestamp
    ) public view virtual returns (uint256);
}
