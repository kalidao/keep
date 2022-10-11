// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Call, Keep} from "../src/Keep.sol";
import {KeepFactory} from "../src/KeepFactory.sol";
import {URIFetcher} from "../src/extensions/URIFetcher.sol";
import {URIRemoteFetcher} from "../src/extensions/URIRemoteFetcher.sol";

import "@std/Test.sol";

contract KeepFactoryTest is Test {
    address keepAddr;
    Keep keep;
    KeepFactory factory;
    URIFetcher uriFetcher;
    URIRemoteFetcher uriRemote;

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

    function setUp() public payable {
        // Create the templates.
        uriRemote = new URIRemoteFetcher(alice);
        uriFetcher = new URIFetcher(alice, uriRemote);
        keep = new Keep(Keep(address(uriFetcher)));
        // Create the factory.
        factory = new KeepFactory(keep);
        // Create the signers.
        signers.push(alice);
        signers.push(bob);
    }

    function testDeploy() public payable {
        factory.deployKeep(name, calls, signers, 2);
    }

    function testDetermination() public payable {
        // Check CREATE2 clones match expected outputs.
        keepAddr = factory.determineKeep(name);
        keep = Keep(keepAddr);
        factory.deployKeep(name, calls, signers, 2);
        assertEq(address(keep), keepAddr);
    }
}
