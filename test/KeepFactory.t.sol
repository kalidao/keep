// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {Call, Keep} from "../src/Keep.sol";
import {KeepFactory} from "../src/KeepFactory.sol";
import {mockName, TestHelpers} from "./utils/helpers.sol";
import "@std/Test.sol";

contract KeepFactoryTest is Test, TestHelpers {
    KeepFactory immutable factory = new KeepFactory();

    /// @dev Users.

    address constant alice = address(0xa);
    address constant bob = address(0xb);

    /// @dev Helpers.

    Call[] calls;

    /// @notice Set up the testing suite.

    function setUp() public payable {}

    function testDeploy() public payable {
        address[] memory signers = new address[](2);
        signers[0] = alice;
        signers[1] = bob;

        factory.deployKeep(mockName, calls, signers, 2);
    }

    function testDetermination() public payable {
        // Check CREATE2 clones match expected outputs.
        (address predicted, ) = factory.determineKeep(mockName);

        address[] memory signers = new address[](2);
        signers[0] = alice;
        signers[1] = bob;

        address deployed = address(
            factory.deployKeep(mockName, calls, signers, 2)
        );
        assertEq(predicted, deployed);
    }
}
