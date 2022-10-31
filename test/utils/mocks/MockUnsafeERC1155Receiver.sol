// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

contract MockUnsafeERC1155Receiver {
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) public payable virtual returns (bytes4) {
        return 0xf23a6e69;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) public payable virtual returns (bytes4) {
        return 0xbc197c89;
    }
}