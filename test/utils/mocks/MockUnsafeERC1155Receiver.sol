// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

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
