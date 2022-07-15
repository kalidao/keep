// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

/// @notice Keep interface
interface IKeep {
    function balanceOf(address account, uint256 id)
        external
        view
        returns (uint256);

    function totalSupply(uint256 id) external view returns (uint256);

    function mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) external payable;

    function burn(
        address from,
        uint256 id,
        uint256 amount
    ) external payable;
}
