// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {Call, Keep} from "../Keep.sol";
import {KeepFactory} from "../KeepFactory.sol";

import "@std/Test.sol";

contract KeepFactoryTest is Test {
    address clubAddr;
    Keep clubSig;
    KeepFactory factory;

    address[] signers;

    /// @dev Users

    address public immutable alice = address(0xa);
    address public immutable bob = address(0xb);

    /// @dev Helpers

    Call[] calls;

    bytes32 name =
        0x5445535400000000000000000000000000000000000000000000000000000000;

    bytes32 name2 =
        0x5445535432000000000000000000000000000000000000000000000000000000;

    /// @notice Set up the testing suite

    function setUp() public {
        // create the templates
        clubSig = new Keep(alice);
        // create the factory
        factory = new KeepFactory(clubSig);
        // Create the signers
        signers.push(alice);
        signers.push(bob);
    }

    function testDeploy() public {
        factory.deploy(calls, signers, 2, name);
    }

    function testDetermination() public {
        (clubAddr, ) = factory.determine(name);
        clubSig = Keep(clubAddr);
        factory.deploy(calls, signers, 2, name);
        // check CREATE2 clones match expected outputs
        bool deployed;
        (clubAddr, deployed) = factory.determine(name);
        assertEq(address(clubSig), clubAddr);
        assertEq(deployed, true);
        (, bool deployed2) = factory.determine(name2);
        assertEq(deployed2, false);
    }
}
