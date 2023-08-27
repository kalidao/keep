// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Call, Keep} from "../src/Keep.sol";
import {KeepFactory} from "../src/KeepFactory.sol";
import {TestHelpers} from "./utils/helpers.sol";
import "@std/Test.sol";

contract KeepFactoryTest is Test, TestHelpers {
    KeepFactory immutable factory = new KeepFactory();

    /// @dev Users.

    address constant alice = address(0xa);
    address constant bob = address(0xb);

    /// @dev Helpers.

    Call[] calls;

    // bytes name =
    //     0x5445535400000000000000000000000000000000000000000000000000000000;

    /// @notice Set up the testing suite.

    function setUp() public payable {}

    function testDeploy() public payable {
        address[] memory signers = new address[](2);
        signers[0] = alice;
        signers[1] = bob;

        factory.deployKeep(getName(), calls, signers, 2);
    }

    function testDetermination() public payable {
        // Check CREATE2 clones match expected outputs.
        (address predicted, ) = factory.determineKeep(getName());

        address[] memory signers = new address[](2);
        signers[0] = alice;
        signers[1] = bob;

        address deployed = address(
            factory.deployKeep(getName(), calls, signers, 2)
        );
        assertEq(predicted, deployed);
    }
}
