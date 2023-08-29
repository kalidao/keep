// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

bytes32 constant mockName = bytes32(abi.encodePacked("Yo"));

contract TestHelpers {
    function getName() public pure returns (bytes32) {
        return bytes32(abi.encodePacked("TEST"));
    }
}
