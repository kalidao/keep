// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Call, Keep} from "../Keep.sol";
import {KeepFactory} from "../KeepFactory.sol";

import "@std/Test.sol";

contract KeepFactoryTest is Test {
    address keepAddr;
    Keep keep;
    KeepFactory factory;

    address[] signers;

    /// @dev Users.

    address public immutable alice = address(0xa);
    address public immutable bob = address(0xb);

    /// @dev Helpers.

    Call[] calls;

    bytes32 name =
        0x5445535400000000000000000000000000000000000000000000000000000000;

    bytes32 name2 =
        0x5445535432000000000000000000000000000000000000000000000000000000;

    /// @notice Set up the testing suite.

    function setUp() public {
        // Create the templates.
        keep = new Keep(Keep(alice));
        // Create the factory.
        factory = new KeepFactory(keep);
        // Create the signers.
        signers.push(alice);
        signers.push(bob);
    }

    function testDeploy() public {
        factory.deployKeep(calls, signers, 2, name);
    }

    function testDetermination() public {
        // Check CREATE2 clones match expected outputs.
        keepAddr = factory.determineKeep(name);
        keep = Keep(keepAddr);
        factory.deployKeep(calls, signers, 2, name);
        assertEq(address(keep), keepAddr);
    }
}
