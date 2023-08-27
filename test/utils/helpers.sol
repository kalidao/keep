// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

contract TestHelpers {
    function getName() public pure returns (bytes memory) {
        return abi.encodePacked("TEST");
    }
}
