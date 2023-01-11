// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @dev Keep core.
import {KeepToken, Operation, Call, Signature, Keep} from "../src/Keep.sol";
import {KeepFactory} from "../src/KeepFactory.sol";
import {URIFetcher} from "../src/extensions/metadata/URIFetcher.sol";
import {URIRemoteFetcher} from "../src/extensions/metadata/URIRemoteFetcher.sol";

/// @dev Kali core.
import {KeepTokenBalances, Proposal, ProposalType, Kali} from "../src/extensions/dao/Kali.sol";
import {KaliFactory} from "../src/extensions/dao/KaliFactory.sol";

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
    address public immutable charlie = address(0xc);

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

        // Mint alice, bob and charlie Kali DAO ID key (0).
        vm.prank(keep);
        Keep(keep).mint(alice, 0, 1, "");
        vm.prank(keep);
        Keep(keep).mint(bob, 0, 1, "");
        vm.prank(keep);
        Keep(keep).mint(charlie, 0, 1, "");
        vm.stopPrank();

        assertEq(Keep(keep).balanceOf(alice, 0), 1);
        assertEq(Keep(keep).balanceOf(bob, 0), 1);
        assertEq(Keep(keep).balanceOf(charlie, 0), 1);

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
        (sent, ) = address(kali).call{value: 10 ether}("");
        assert(sent);

        // Bump time.
        vm.warp(block.timestamp + 1000);
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

    function testProposal() public payable {
        vm.warp(block.timestamp + 1 days);

        // Check initial ETH.
        assertEq(address(kali).balance, 10 ether);
        assertEq(alice.balance, 0 ether);

        // Setup proposal.
        address[] memory accounts = new address[](1);
        accounts[0] = alice;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1 ether;

        bytes[] memory payloads = new bytes[](1);
        payloads[0] = "";

        // Propose as alice.
        vm.prank(alice);
        // Make proposal.
        uint256 proposalId = kali.propose(
            ProposalType.CALL,
            name1,
            accounts,
            amounts,
            payloads
        );
        vm.stopPrank();

        // Check proposal Id.
        assertEq(proposalId, 1);

        // Check proposal creation.
        (, , , uint40 creationTime, , ) = kali.proposals(proposalId);
        assertEq(creationTime, block.timestamp);
        assert(block.timestamp != 0);

        // Check proposal hash.
        (, bytes32 digest, , , , ) = kali.proposals(proposalId);
        bytes32 proposalHash = keccak256(
            abi.encode(ProposalType.CALL, name1, accounts, amounts, payloads)
        );
        assertEq(digest, proposalHash);

        // Skip ahead in voting period.
        vm.warp(block.timestamp + 12 hours);

        // Vote as alice.
        vm.prank(alice);
        kali.vote(proposalId, true, "");
        vm.stopPrank();

        // Vote as bob.
        vm.prank(bob);
        kali.vote(proposalId, true, "");
        vm.stopPrank();

        // Check proposal votes.
        (, , , , uint216 yesVotes, ) = kali.proposals(proposalId);
        assertEq(yesVotes, 2);
        /*
        // Process proposal.
        (bool passed, ) = kali.processProposal(
            proposalId,
            ProposalType.CALL,
            name1,
            accounts, 
            amounts, 
            payloads
        );
        assert(passed);
        
        // Check ETH was sent.
        assertEq(address(kali).balance, 10 ether);
        assertEq(alice.balance, 0 ether);*/
    }
}
