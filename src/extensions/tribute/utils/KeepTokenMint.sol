// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @dev Contract helper for Keep token minting.
abstract contract KeepTokenMint {
    function balanceOf(address account, uint256 id)
        public
        view
        virtual
        returns (uint256);

    function mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) public virtual;
}
