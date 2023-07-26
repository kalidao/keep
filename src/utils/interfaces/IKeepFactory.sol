// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IKeepFactory {
    event Deployed(address indexed keep, address[] signers, uint256 threshold);

    struct Call {
        uint8 op;
        address to;
        uint256 value;
        bytes data;
    }

    function deployKeep(
        bytes32 name,
        Call[] memory calls,
        address[] memory signers,
        uint256 threshold
    ) external payable;

    function determineKeep(bytes32 name) external view returns (address);

    function multicall(
        bytes[] memory data
    ) external payable returns (bytes[] memory);
}
