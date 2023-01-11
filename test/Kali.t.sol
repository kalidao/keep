// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @dev Keep core.
import {KeepToken, Operation, Call, Signature, Keep} from "../src/Keep.sol";
import {KeepFactory} from "../src/KeepFactory.sol";
import {URIFetcher} from "../src/extensions/metadata/URIFetcher.sol";
import {URIRemoteFetcher} from "../src/extensions/metadata/URIRemoteFetcher.sol";

/// @dev Kali core.
import {KeepTokenBalances, Kali, KaliFactory} from "../src/extensions/dao/KaliFactory.sol";

import "@std/Test.sol";

contract KaliTest is Test {
    address keepAddr;
    address kaliAddr;

    URIFetcher uriFetcher;
    URIRemoteFetcher uriRemote;

    address keep;
    KeepFactory keepFactory;

    Kali kali;
    KaliFactory kaliFactory;

    address[] signers;

    /// @dev Users.

    address public immutable alice = address(0xa);
    address public immutable bob = address(0xb);

    /// @dev Helpers.

    Call[] calls;

    bytes32 name1 =
        0x5445535400000000000000000000000000000000000000000000000000000000;

    bytes32 name2 =
        0x5445535432000000000000000000000000000000000000000000000000000000;

    /// @notice Set up the testing suite.

    function setUp() public payable {
        // Create the Keep templates.
        uriRemote = new URIRemoteFetcher(alice);
        uriFetcher = new URIFetcher(alice, uriRemote);
        keep = address(new Keep(Keep(address(uriFetcher))));
        // Create the Keep factory.
        keepFactory = new KeepFactory(Keep(keep));
        // Create the Signer[] for setup.
        address[] memory setupSigners = new address[](2);
        setupSigners[0] = alice > bob ? bob : alice;
        setupSigners[1] = alice > bob ? alice : bob;
        // Store the Keep signers.
        signers.push(alice);
        signers.push(bob);
        // Initialize Keep from factory.
        keepAddr = keepFactory.determineKeep(name1);
        keep = keepAddr;
        keepFactory.deployKeep(name1, calls, setupSigners, 2);

        // Create the Kali template.
        kali = new Kali();
        // Create the Kali factory.
        kaliFactory = new KaliFactory(kali);

        // Prime dummy inputs;
        bytes[] memory dummyCalls = new bytes[](2);
        dummyCalls[0] = "";
        dummyCalls[1] = "";

        uint120[4] memory govSettings;
        govSettings[0] = 1 days;
        govSettings[1] = 0;
        govSettings[2] = 20;
        govSettings[3] = 52;

        kaliAddr = kaliFactory.determineKali(KeepTokenBalances(keep), 0, name1);

        kali = Kali(kaliAddr);

        kaliFactory.deployKali(
            KeepTokenBalances(keep),
            0,
            name1, // create2 salt.
            "DAO",
            setupSigners,
            dummyCalls,
            govSettings
        );

        bool sent;

        // Deposit 1 ETH to Keep.
        (sent, ) = keep.call{value: 1 ether}("");
        assert(sent);

        // Deposit 10 ETH to Kali.
        (sent, ) = kaliAddr.call{value: 10 ether}("");
        assert(sent);
    }

    function testDeploy() public payable {
        // Create the Signer[] for setup.
        address[] memory setupSigners = new address[](2);
        setupSigners[0] = alice > bob ? bob : alice;
        setupSigners[1] = alice > bob ? alice : bob;

        // Prime dummy inputs;
        bytes[] memory dummyCalls = new bytes[](2);
        dummyCalls[0] = "";
        dummyCalls[1] = "";

        uint120[4] memory govSettings;
        govSettings[0] = 1 days;
        govSettings[1] = 0;
        govSettings[2] = 20;
        govSettings[3] = 52;

        kaliFactory.deployKali(
            KeepTokenBalances(keep),
            0,
            name2, // create2 salt.
            "DAO",
            setupSigners,
            dummyCalls,
            govSettings
        );
    }

    function testDetermination() public payable {
        // Check CREATE2 clones match expected outputs.
        address computedAddr = kaliFactory.determineKali(
            KeepTokenBalances(keep),
            0,
            name1
        );

        assertEq(address(kali), computedAddr);
    }
}
