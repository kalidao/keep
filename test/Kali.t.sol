// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @dev Keep core.
import {KeepToken, Operation, Call, Signature, Keep} from "../src/Keep.sol";
import {KeepFactory} from "../src/KeepFactory.sol";
import {URIFetcher} from "../src/extensions/metadata/URIFetcher.sol";

/// @dev Kali core.
import {KeepTokenManager, Proposal, ProposalType, VoteType, Kali} from "../src/extensions/dao/Kali.sol";
import {KaliFactory} from "../src/extensions/dao/KaliFactory.sol";

/// @dev Mocks.
import {MockERC20} from "@solbase/test/utils/mocks/MockERC20.sol";
import {MockERC721} from "@solbase/test/utils/mocks/MockERC721.sol";
import {MockERC1155} from "@solbase/test/utils/mocks/MockERC1155.sol";
import {MockERC1271Wallet} from "@solbase/test/utils/mocks/MockERC1271Wallet.sol";
import {MockUnsafeERC1155Receiver} from "./utils/mocks/MockUnsafeERC1155Receiver.sol";

import "@std/Test.sol";

error Initialized();

error PeriodBounds();

error QuorumMax();

error SupermajorityBounds();

error TypeBounds();

error InvalidProposal();

error Sponsored();

error AlreadyVoted();

contract KaliTest is Test, Keep(Keep(address(0))) {
    address keepAddr;
    address kaliAddr;

    address keep;
    KeepFactory keepFactory;

    address kali;
    KaliFactory kaliFactory;

    MockERC20 internal mockDai;
    MockERC721 internal mockNFT;
    MockERC1155 internal mock1155;
    MockERC1271Wallet internal mockERC1271Wallet;
    MockUnsafeERC1155Receiver internal mockUnsafeERC1155Receiver;

    address[] signers;

    /// @dev Users.

    address public immutable alice = makeAddr("alice");
    address public immutable bob = makeAddr("bob");
    address public immutable charlie = makeAddr("charlie");
    address public immutable dave = makeAddr("dave");

    /// @dev Helpers.

    Call[] calls;

    string internal constant description = "TEST";

    bytes32 internal constant name1 =
        0x5445535400000000000000000000000000000000000000000000000000000000;

    bytes32 internal constant name2 =
        0x5445535432000000000000000000000000000000000000000000000000000000;

    /// -----------------------------------------------------------------------
    /// Kali Setup Tests
    /// -----------------------------------------------------------------------

    /// @notice Set up the testing suite.

    function setUp() public payable {
        mockDai = new MockERC20("Dai", "DAI", 18);
        mockNFT = new MockERC721("NFT", "NFT");
        mock1155 = new MockERC1155();
        mockERC1271Wallet = new MockERC1271Wallet(alice);
        mockUnsafeERC1155Receiver = new MockUnsafeERC1155Receiver();

        // Create the Keep templates.
        keep = address(new Keep(Keep(address(address(0)))));
        // Create the Keep factory.
        keepFactory = new KeepFactory(keep);
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

        // Mint alice, bob and charlie Kali Keep DAO ID key (0).
        vm.prank(keep);
        Keep(keep).mint(alice, 0, 1, "");
        vm.prank(keep);
        Keep(keep).mint(bob, 0, 1, "");
        vm.prank(keep);
        Keep(keep).mint(charlie, 0, 1, "");
        vm.stopPrank();

        // Check balances.
        assertEq(Keep(keep).balanceOf(alice, 0), 1);
        assertEq(Keep(keep).balanceOf(bob, 0), 1);
        assertEq(Keep(keep).balanceOf(charlie, 0), 1);

        // Create the Kali template.
        kali = address(new Kali());
        // Create the Kali factory.
        kaliFactory = new KaliFactory(kali);

        // Prime dummy inputs;
        Call[] memory dummyCall = new Call[](1);

        uint120[4] memory govSettings;
        govSettings[0] = 1 days;
        govSettings[1] = 0;
        govSettings[2] = 20;
        govSettings[3] = 52;

        kali = kaliFactory.determineKali(KeepTokenManager(keep), 0, name1);

        kaliFactory.deployKali(
            KeepTokenManager(keep),
            0,
            name1, // create2 salt.
            dummyCall,
            "DAO",
            govSettings
        );

        // Mint Core Key ID uber permission to DAO.
        vm.prank(keep);
        Keep(keep).mint(kali, CORE_KEY, 1, "");
        vm.stopPrank();

        assertEq(Keep(keep).balanceOf(kali, CORE_KEY), 1);

        bool sent;

        // Deposit 1 ETH to Keep.
        (sent, ) = keep.call{value: 1 ether}("");
        assert(sent);

        // Deposit 10 ETH to Kali.
        (sent, ) = kali.call{value: 10 ether}("");
        assert(sent);

        // Bump time.
        vm.warp(block.timestamp + 1000);

        // Mint mock ERC20.
        mockDai.mint(address(this), 1_000_000_000 ether);
        mockDai.mint(kali, 1_000_000_000 ether);
        // Mint mock 721.
        mockNFT.mint(address(this), 1);
        // Mint mock 1155.
        mock1155.mint(address(this), 1, 1, "");
    }

    /// @notice Check deployment.

    function testDetermination() public payable {
        // Check CREATE2 clones match expected outputs.
        address computedAddr = kaliFactory.determineKali(
            KeepTokenManager(keep),
            0,
            name1
        );

        assertEq(kali, computedAddr);
    }

    function testDeploy() public payable {
        // Prime dummy inputs;
        Call[] memory dummyCall = new Call[](1);

        uint120[4] memory govSettings;
        govSettings[0] = 1 days;
        govSettings[1] = 0;
        govSettings[2] = 20;
        govSettings[3] = 52;

        kaliFactory.deployKali(
            KeepTokenManager(keep),
            0,
            name2, // create2 salt.
            dummyCall,
            "DAO",
            govSettings
        );
    }

    function testFailDeploy() public payable {
        // Create the Signer[].
        address[] memory setupSigners = new address[](2);
        setupSigners[0] = alice > bob ? bob : alice;
        setupSigners[1] = alice > bob ? alice : bob;

        // Prime dummy inputs;
        Call[] memory dummyCall = new Call[](1);

        // Check against zero voting period.
        uint120[4] memory govSettings;
        govSettings[0] = 0;
        govSettings[1] = 0;
        govSettings[2] = 20;
        govSettings[3] = 52;

        vm.expectRevert(PeriodBounds.selector);
        kaliFactory.deployKali(
            KeepTokenManager(keep),
            0,
            name2, // create2 salt.
            dummyCall,
            "DAO",
            govSettings
        );

        // Check against excessive voting period.
        govSettings[0] = 366 days;

        vm.expectRevert(PeriodBounds.selector);
        kaliFactory.deployKali(
            KeepTokenManager(keep),
            0,
            name2, // create2 salt.
            dummyCall,
            "DAO",
            govSettings
        );

        // Check against excessive grace period.
        govSettings[0] = 1 days;
        govSettings[1] = 366 days;

        vm.expectRevert(PeriodBounds.selector);
        kaliFactory.deployKali(
            KeepTokenManager(keep),
            0,
            name2, // create2 salt.
            dummyCall,
            "DAO",
            govSettings
        );

        // Check against excessive quorum.
        govSettings[0] = 1 days;
        govSettings[1] = 0;
        govSettings[2] = 101;

        vm.expectRevert(QuorumMax.selector);
        kaliFactory.deployKali(
            KeepTokenManager(keep),
            0,
            name2, // create2 salt.
            dummyCall,
            "DAO",
            govSettings
        );

        // Check against zero supermajority.
        govSettings[0] = 1 days;
        govSettings[1] = 0;
        govSettings[2] = 0;
        govSettings[3] = 0;

        vm.expectRevert(SupermajorityBounds.selector);
        kaliFactory.deployKali(
            KeepTokenManager(keep),
            0,
            name2, // create2 salt.
            dummyCall,
            "DAO",
            govSettings
        );

        // Check against excessive supermajority.
        govSettings[0] = 1 days;
        govSettings[1] = 0;
        govSettings[2] = 0;
        govSettings[3] = 101;

        vm.expectRevert(SupermajorityBounds.selector);
        kaliFactory.deployKali(
            KeepTokenManager(keep),
            0,
            name2, // create2 salt.
            dummyCall,
            "DAO",
            govSettings
        );

        // Check against repeat initialization.
        govSettings[0] = 1 days;
        govSettings[1] = 0;
        govSettings[2] = 20;
        govSettings[3] = 52;

        kaliFactory.deployKali(
            KeepTokenManager(keep),
            0,
            name2, // create2 salt.
            dummyCall,
            "DAO",
            govSettings
        );

        vm.expectRevert(Initialized.selector);
        kaliFactory.deployKali(
            KeepTokenManager(keep),
            0,
            name2, // create2 salt.
            dummyCall,
            "DAO",
            govSettings
        );
    }

    /// -----------------------------------------------------------------------
    /// Kali State Tests
    /// -----------------------------------------------------------------------

    function testName() public payable {
        assertEq(Kali(kali).name(), string(abi.encodePacked(name1)));
    }

    function testToken() public payable {
        assert(Kali(kali).token() == KeepTokenManager(keep));
    }

    function testTokenId() public payable {
        assertEq(Kali(kali).tokenId(), 0);
    }

    function testDaoURI() public payable {
        assertEq(Kali(kali).daoURI(), "DAO");
    }

    function testVotingPeriod() public payable {
        assertEq(Kali(kali).votingPeriod(), 1 days);
    }

    function testGracePeriod() public payable {
        assertEq(Kali(kali).gracePeriod(), 0);
    }

    function testQuorum() public payable {
        assertEq(Kali(kali).quorum(), 20);
    }

    function testSupermajority() public payable {
        assertEq(Kali(kali).supermajority(), 52);
    }

    function testSupportsInterface() public payable {
        assert(Kali(kali).supportsInterface(0x01ffc9a7));
        assert(Kali(kali).supportsInterface(0x150b7a02));
        assert(Kali(kali).supportsInterface(0x4e2312e0));
    }

    /// -----------------------------------------------------------------------
    /// Kali Receiver Tests
    /// -----------------------------------------------------------------------

    function testERC20Receiver() public payable {
        mockDai.transfer(kali, 1 ether);
    }

    function testERC721Receiver() public payable {
        mockNFT.transferFrom(address(this), kali, 1);
    }

    function testERC1155Receiver() public payable {
        mock1155.safeTransferFrom(address(this), kali, 1, 1, "");
    }

    function testERC1155BatchReceiver() public payable {
        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 1;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1;
        amounts[1] = 0;

        mock1155.safeBatchTransferFrom(address(this), kali, ids, amounts, "");
    }

    /// -----------------------------------------------------------------------
    /// Kali Proposal Tests
    /// -----------------------------------------------------------------------

    function testProposalCreation() public payable {
        vm.warp(block.timestamp + 1 days);

        // Setup proposal.
        Call[] memory call = new Call[](1);

        call[0].op = Operation.call;
        call[0].to = alice;
        call[0].value = 1 ether;
        call[0].data = "";

        // Propose as alice.
        vm.prank(alice);
        (uint256 proposalId, ) = Kali(kali).propose(
            call,
            ProposalType.CALL,
            "test"
        );
        vm.stopPrank();

        // Check proposal creation.
        (, , , uint40 creationTime, , ) = Kali(kali).proposals(proposalId);
        assertEq(creationTime, block.timestamp);
        assert(block.timestamp != 0);

        // Check proposal hash.
        (, bytes32 digest, , , , ) = Kali(kali).proposals(proposalId);
        bytes32 proposalHash = keccak256(
            abi.encode(call, ProposalType.CALL, "test")
        );
        assertEq(digest, proposalHash);
    }

    function testFailProposalCreation() public payable {
        vm.warp(block.timestamp + 1 days);

        // Setup proposal.
        Call[] memory call = new Call[](1);

        call[0].op = Operation.call;
        call[0].to = address(0);
        call[0].value = 0;
        call[0].data = "";

        vm.prank(alice);
        vm.expectRevert(PeriodBounds.selector);
        Kali(kali).propose(call, ProposalType.VPERIOD, "test");
        vm.stopPrank();

        call[0].value = 366;

        vm.prank(alice);
        vm.expectRevert(PeriodBounds.selector);
        Kali(kali).propose(call, ProposalType.VPERIOD, "test");
        vm.stopPrank();

        vm.prank(alice);
        vm.expectRevert(PeriodBounds.selector);
        Kali(kali).propose(call, ProposalType.GPERIOD, "test");
        vm.stopPrank();

        vm.prank(alice);
        vm.expectRevert(QuorumMax.selector);
        Kali(kali).propose(call, ProposalType.QUORUM, "test");
        vm.stopPrank();

        vm.prank(alice);
        vm.expectRevert(SupermajorityBounds.selector);
        Kali(kali).propose(call, ProposalType.SUPERMAJORITY, "test");
        vm.stopPrank();

        call[0].value = 50;

        vm.prank(alice);
        vm.expectRevert(SupermajorityBounds.selector);
        Kali(kali).propose(call, ProposalType.SUPERMAJORITY, "test");
        vm.stopPrank();

        vm.prank(alice);
        vm.expectRevert(TypeBounds.selector);
        Kali(kali).propose(call, ProposalType.TYPE, "test");
        vm.stopPrank();

        call[0].value = 1;
        call[0].value = 50;

        vm.prank(alice);
        vm.expectRevert(TypeBounds.selector);
        Kali(kali).propose(call, ProposalType.TYPE, "test");
        vm.stopPrank();
    }

    function testProposal() public payable {
        // Check initial ETH.
        assertEq(kali.balance, 10 ether);
        assertEq(alice.balance, 0 ether);

        // Setup proposal.
        Call[] memory call = new Call[](1);

        call[0].op = Operation.call;
        call[0].to = alice;
        call[0].value = 1 ether;
        call[0].data = "";

        // Propose as alice.
        vm.prank(alice);
        (uint256 proposalId, uint40 creationTime) = Kali(kali).propose(
            call,
            ProposalType.CALL,
            "test"
        );
        vm.stopPrank();

        assertEq(creationTime, block.timestamp);

        // Skip ahead in voting period.
        vm.warp(block.timestamp + 12 hours);

        // Vote as alice.
        vm.prank(alice);
        Kali(kali).vote(proposalId, true, "");
        vm.stopPrank();

        // Vote as bob.
        vm.prank(bob);
        Kali(kali).vote(proposalId, true, "");
        vm.stopPrank();

        // Check proposal votes.
        (, , , , uint216 yesVotes, uint216 noVotes) = Kali(kali).proposals(
            proposalId
        );
        assertEq(yesVotes, 2);
        assertEq(noVotes, 0);

        // Process proposal.
        bool passed = Kali(kali).processProposal(
            proposalId,
            call,
            ProposalType.CALL,
            "test"
        );
        assert(passed);

        // Check proposal state.
        (bool didPass, bool processed) = Kali(kali).proposalStates(proposalId);
        assert(didPass);
        assert(processed);

        // Check ETH was sent.
        assertEq(kali.balance, 9 ether);
        assertEq(alice.balance, 1 ether);
    }

    function testProposalRepeatProcessingFail() public payable {
        // Setup proposal.
        Call[] memory call = new Call[](1);

        call[0].op = Operation.call;
        call[0].to = alice;
        call[0].value = 1 ether;
        call[0].data = "";

        // Propose as alice.
        vm.prank(alice);
        (uint256 proposalId, ) = Kali(kali).propose(
            call,
            ProposalType.CALL,
            "test"
        );
        vm.stopPrank();

        // Skip ahead in voting period.
        vm.warp(block.timestamp + 12 hours);

        // Vote as alice.
        vm.prank(alice);
        Kali(kali).vote(proposalId, true, "");
        vm.stopPrank();

        // Vote as bob.
        vm.prank(bob);
        Kali(kali).vote(proposalId, true, "");
        vm.stopPrank();

        // Check proposal votes.
        (, , , , uint216 yesVotes, uint216 noVotes) = Kali(kali).proposals(
            proposalId
        );
        assertEq(yesVotes, 2);
        assertEq(noVotes, 0);

        // Process proposal.
        bool passed = Kali(kali).processProposal(
            proposalId,
            call,
            ProposalType.CALL,
            "test"
        );
        assert(passed);

        // Process proposal.
        vm.expectRevert(InvalidProposal.selector);
        Kali(kali).processProposal(proposalId, call, ProposalType.CALL, "test");
    }

    function testFailProposalRepeatVoting() public payable {
        // Setup proposal.
        Call[] memory call = new Call[](1);

        call[0].op = Operation.call;
        call[0].to = alice;
        call[0].value = 1 ether;
        call[0].data = "";

        // Propose as alice.
        vm.prank(alice);
        (uint256 proposalId, ) = Kali(kali).propose(
            call,
            ProposalType.CALL,
            "test"
        );
        vm.stopPrank();

        // Skip ahead in voting period.
        vm.warp(block.timestamp + 12 hours);

        // Vote as alice.
        vm.prank(alice);
        Kali(kali).vote(proposalId, true, "");
        vm.stopPrank();

        // Vote as bob.
        vm.prank(bob);
        Kali(kali).vote(proposalId, false, "");
        vm.expectRevert(AlreadyVoted.selector);
        Kali(kali).vote(proposalId, true, "");
        vm.stopPrank();

        // Check proposal votes.
        (, , , , uint216 yesVotes, uint216 noVotes) = Kali(kali).proposals(
            proposalId
        );
        assertEq(yesVotes, 1);
        assertEq(noVotes, 1);
    }

    function testProposalSponsorship() public payable {
        // Setup proposal.
        Call[] memory call = new Call[](1);

        call[0].op = Operation.call;
        call[0].to = alice;
        call[0].value = 1 ether;
        call[0].data = "";

        // Propose as dave.
        vm.prank(dave);
        (uint256 proposalId, uint40 creationTime) = Kali(kali).propose(
            call,
            ProposalType.CALL,
            "test"
        );
        vm.stopPrank();

        // Check proposal creation time is zero.
        assertEq(creationTime, 0);
        (, , , creationTime, , ) = Kali(kali).proposals(proposalId);
        assertEq(creationTime, 0);

        // Sponsor as alice.
        vm.prank(alice);
        Kali(kali).sponsorProposal(proposalId);
        vm.stopPrank();

        // Check proposal creation time is current.
        (, , , creationTime, , ) = Kali(kali).proposals(proposalId);
        assertEq(creationTime, block.timestamp);

        // Check can't sponsor after.
        vm.prank(alice);
        vm.expectRevert(Sponsored.selector);
        Kali(kali).sponsorProposal(proposalId);
        vm.stopPrank();

        // Propose as dave.
        vm.prank(dave);
        (proposalId, creationTime) = Kali(kali).propose(
            call,
            ProposalType.CALL,
            "test"
        );
        vm.stopPrank();

        // Check proposal creation time is zero.
        assertEq(creationTime, 0);
        (, , , creationTime, , ) = Kali(kali).proposals(proposalId);
        assertEq(creationTime, 0);

        // Sponsor as alice.
        vm.prank(alice);
        Kali(kali).sponsorProposal(proposalId);
        vm.stopPrank();

        // Check prev prop storage.
        (uint256 prevProposal, , , , , ) = Kali(kali).proposals(proposalId);
        assertEq(prevProposal, proposalId - 1);

        // Propose as alice.
        vm.prank(alice);
        (proposalId, creationTime) = Kali(kali).propose(
            call,
            ProposalType.CALL,
            "test"
        );
        vm.stopPrank();

        // Check proposal creation time.
        assertEq(creationTime, block.timestamp);
        (, , , creationTime, , ) = Kali(kali).proposals(proposalId);
        assertEq(creationTime, block.timestamp);

        // Propose as alice.
        vm.prank(alice);
        (proposalId, ) = Kali(kali).propose(call, ProposalType.CALL, "test");
        vm.stopPrank();

        // Check can't sponsor after.
        vm.prank(alice);
        vm.expectRevert(Sponsored.selector);
        Kali(kali).sponsorProposal(proposalId);
        vm.stopPrank();
    }

    function testProposalCancellation() public payable {
        // Setup proposal.
        Call[] memory call = new Call[](1);

        call[0].op = Operation.call;
        call[0].to = alice;
        call[0].value = 1 ether;
        call[0].data = "";

        // Propose as dave and cancel.
        vm.prank(dave);
        (uint256 proposalId, ) = Kali(kali).propose(
            call,
            ProposalType.CALL,
            "test"
        );
        vm.prank(dave);
        Kali(kali).cancelProposal(proposalId);
        vm.expectRevert(Unauthorized.selector);
        Kali(kali).cancelProposal(proposalId);
        vm.stopPrank();

        // Propose as dave and fail after sponsored.
        vm.prank(dave);
        (proposalId, ) = Kali(kali).propose(call, ProposalType.CALL, "test");
        vm.stopPrank();

        vm.prank(alice);
        Kali(kali).sponsorProposal(proposalId);
        vm.stopPrank();

        vm.prank(dave);
        vm.expectRevert(Sponsored.selector);
        Kali(kali).cancelProposal(proposalId);
        vm.stopPrank();
    }

    function testProposalVoteStored() public payable {
        // Check initial alice DAO (0) balance.
        assertEq(Keep(keep).balanceOf(alice, 0), 1);

        // Setup proposal.
        Call[] memory call = new Call[](1);

        call[0].op = Operation.call;
        call[0].to = alice;
        call[0].value = 1;
        call[0].data = "";

        // Propose as alice.
        vm.prank(alice);
        (uint256 proposalId, ) = Kali(kali).propose(
            call,
            ProposalType.BURN,
            "test"
        );
        vm.stopPrank();

        // Skip ahead in voting period.
        vm.warp(block.timestamp + 12 hours);

        // Vote as alice.
        vm.prank(alice);
        Kali(kali).vote(proposalId, true, "");
        vm.stopPrank();

        // Vote as bob.
        vm.prank(bob);
        Kali(kali).vote(proposalId, true, "");
        vm.stopPrank();

        // Check proposal votes.
        (, , , , uint216 yesVotes, uint216 noVotes) = Kali(kali).proposals(
            proposalId
        );
        assertEq(yesVotes, 2);
        assertEq(noVotes, 0);

        assert(Kali(kali).voted(1, alice));
        assert(Kali(kali).voted(1, bob));
    }

    function testMintProposal() public payable {
        // Check initial alice DAO (0) balance.
        assertEq(Keep(keep).balanceOf(alice, 0), 1);

        // Setup proposal.
        Call[] memory call = new Call[](1);

        call[0].op = Operation.call;
        call[0].to = alice;
        call[0].value = 1;
        call[0].data = "";

        // Propose as alice.
        vm.prank(alice);
        (uint256 proposalId, ) = Kali(kali).propose(
            call,
            ProposalType.MINT,
            "test"
        );
        vm.stopPrank();

        // Skip ahead in voting period.
        vm.warp(block.timestamp + 12 hours);

        // Vote as alice.
        vm.prank(alice);
        Kali(kali).vote(proposalId, true, "");
        vm.stopPrank();

        // Vote as bob.
        vm.prank(bob);
        Kali(kali).vote(proposalId, true, "");
        vm.stopPrank();

        // Check proposal votes.
        (, , , , uint216 yesVotes, uint216 noVotes) = Kali(kali).proposals(
            proposalId
        );
        assertEq(yesVotes, 2);
        assertEq(noVotes, 0);

        // Process proposal.
        bool passed = Kali(kali).processProposal(
            proposalId,
            call,
            ProposalType.MINT,
            "test"
        );
        assert(passed);

        // Check proposal state.
        (bool didPass, bool processed) = Kali(kali).proposalStates(proposalId);
        assert(didPass);
        assert(processed);

        // Check processed alice DAO (0) balance.
        assertEq(Keep(keep).balanceOf(alice, 0), 2);
    }

    function testMultiMintProposal() public payable {
        // Check initial DAO (0) balances.
        assertEq(Keep(keep).balanceOf(alice, 0), 1);
        assertEq(Keep(keep).balanceOf(bob, 0), 1);
        assertEq(Keep(keep).balanceOf(charlie, 0), 1);
        assertEq(Keep(keep).balanceOf(dave, 0), 0);

        // Setup proposal.
        Call[] memory call = new Call[](4);

        call[0].op = Operation.call;
        call[0].to = alice;
        call[0].value = 1;
        call[0].data = "";

        call[1].op = Operation.call;
        call[1].to = bob;
        call[1].value = 1;
        call[1].data = "";

        call[2].op = Operation.call;
        call[2].to = charlie;
        call[2].value = 1;
        call[2].data = "";

        call[3].op = Operation.call;
        call[3].to = dave;
        call[3].value = 1;
        call[3].data = "";

        // Propose as alice.
        vm.prank(alice);
        (uint256 proposalId, ) = Kali(kali).propose(
            call,
            ProposalType.MINT,
            "test"
        );
        vm.stopPrank();

        // Skip ahead in voting period.
        vm.warp(block.timestamp + 12 hours);

        // Vote as alice.
        vm.prank(alice);
        Kali(kali).vote(proposalId, true, "");
        vm.stopPrank();

        // Vote as bob.
        vm.prank(bob);
        Kali(kali).vote(proposalId, true, "");
        vm.stopPrank();

        // Check proposal votes.
        (, , , , uint216 yesVotes, uint216 noVotes) = Kali(kali).proposals(
            proposalId
        );
        assertEq(yesVotes, 2);
        assertEq(noVotes, 0);

        // Process proposal.
        bool passed = Kali(kali).processProposal(
            proposalId,
            call,
            ProposalType.MINT,
            "test"
        );
        assert(passed);

        // Check proposal state.
        (bool didPass, bool processed) = Kali(kali).proposalStates(proposalId);
        assert(didPass);
        assert(processed);

        // Check processed DAO (0) balances.
        assertEq(Keep(keep).balanceOf(alice, 0), 2);
        assertEq(Keep(keep).balanceOf(bob, 0), 2);
        assertEq(Keep(keep).balanceOf(charlie, 0), 2);
        assertEq(Keep(keep).balanceOf(dave, 0), 1);
    }

    function testBurnProposal() public payable {
        // Check initial alice DAO (0) balance.
        assertEq(Keep(keep).balanceOf(alice, 0), 1);

        // Setup proposal.
        Call[] memory call = new Call[](1);

        call[0].op = Operation.call;
        call[0].to = alice;
        call[0].value = 1;
        call[0].data = "";

        // Propose as alice.
        vm.prank(alice);
        (uint256 proposalId, ) = Kali(kali).propose(
            call,
            ProposalType.BURN,
            "test"
        );
        vm.stopPrank();

        // Skip ahead in voting period.
        vm.warp(block.timestamp + 12 hours);

        // Vote as alice.
        vm.prank(alice);
        Kali(kali).vote(proposalId, true, "");
        vm.stopPrank();

        // Vote as bob.
        vm.prank(bob);
        Kali(kali).vote(proposalId, true, "");
        vm.stopPrank();

        // Process proposal.
        bool passed = Kali(kali).processProposal(
            proposalId,
            call,
            ProposalType.BURN,
            "test"
        );
        assert(passed);

        // Check processed alice DAO (0) balance.
        assertEq(Keep(keep).balanceOf(alice, 0), 0);
    }

    function testMultiBurnProposal() public payable {
        // Check initial DAO (0) balances.
        assertEq(Keep(keep).balanceOf(alice, 0), 1);
        assertEq(Keep(keep).balanceOf(bob, 0), 1);

        // Setup proposal.
        Call[] memory call = new Call[](2);

        call[0].op = Operation.call;
        call[0].to = alice;
        call[0].value = 1;
        call[0].data = "";

        call[1].op = Operation.call;
        call[1].to = bob;
        call[1].value = 1;
        call[1].data = "";

        // Propose as alice.
        vm.prank(alice);
        (uint256 proposalId, ) = Kali(kali).propose(
            call,
            ProposalType.BURN,
            "test"
        );
        vm.stopPrank();

        // Skip ahead in voting period.
        vm.warp(block.timestamp + 12 hours);

        // Vote as alice.
        vm.prank(alice);
        Kali(kali).vote(proposalId, true, "");
        vm.stopPrank();

        // Vote as bob.
        vm.prank(bob);
        Kali(kali).vote(proposalId, true, "");
        vm.stopPrank();

        // Process proposal.
        bool passed = Kali(kali).processProposal(
            proposalId,
            call,
            ProposalType.BURN,
            "test"
        );
        assert(passed);

        // Check processed DAO (0) balances.
        assertEq(Keep(keep).balanceOf(alice, 0), 0);
        assertEq(Keep(keep).balanceOf(bob, 0), 0);
    }

    function testCallProposal() public payable {
        // Check initial alice Dai balance.
        assertEq(mockDai.balanceOf(alice), 0);
        assertEq(mockDai.balanceOf(kali), 1_000_000_000 ether);

        // Setup proposal.
        Call[] memory call = new Call[](1);

        bytes memory data = abi.encodeCall(
            mockDai.transfer,
            (alice, 1_000_000_000 ether)
        );

        call[0].op = Operation.call;
        call[0].to = address(mockDai);
        call[0].value = 0;
        call[0].data = data;

        // Propose as alice.
        vm.prank(alice);
        (uint256 proposalId, ) = Kali(kali).propose(
            call,
            ProposalType.CALL,
            "test"
        );
        vm.stopPrank();

        // Skip ahead in voting period.
        vm.warp(block.timestamp + 12 hours);

        // Vote as alice.
        vm.prank(alice);
        Kali(kali).vote(proposalId, true, "");
        vm.stopPrank();

        // Vote as bob.
        vm.prank(bob);
        Kali(kali).vote(proposalId, true, "");
        vm.stopPrank();

        // Process proposal.
        bool passed = Kali(kali).processProposal(
            proposalId,
            call,
            ProposalType.CALL,
            "test"
        );
        assert(passed);

        // Check processed alice Dai balance.
        assertEq(mockDai.balanceOf(alice), 1_000_000_000 ether);
        assertEq(mockDai.balanceOf(kali), 0);
    }

    function testMultiCallProposal() public payable {
        // Check initial Dai balances.
        assertEq(mockDai.balanceOf(alice), 0);
        assertEq(mockDai.balanceOf(bob), 0);
        assertEq(mockDai.balanceOf(kali), 1_000_000_000 ether);

        // Setup proposal.
        Call[] memory call = new Call[](2);

        bytes memory data = abi.encodeCall(
            mockDai.transfer,
            (alice, 500_000_000 ether)
        );
        bytes memory data1 = abi.encodeCall(
            mockDai.transfer,
            (bob, 500_000_000 ether)
        );

        call[0].op = Operation.call;
        call[0].to = address(mockDai);
        call[0].value = 0;
        call[0].data = data;

        call[1].op = Operation.call;
        call[1].to = address(mockDai);
        call[1].value = 0;
        call[1].data = data1;

        // Propose as alice.
        vm.prank(alice);
        (uint256 proposalId, ) = Kali(kali).propose(
            call,
            ProposalType.CALL,
            "test"
        );
        vm.stopPrank();

        // Skip ahead in voting period.
        vm.warp(block.timestamp + 12 hours);

        // Vote as alice.
        vm.prank(alice);
        Kali(kali).vote(proposalId, true, "");
        vm.stopPrank();

        // Vote as bob.
        vm.prank(bob);
        Kali(kali).vote(proposalId, true, "");
        vm.stopPrank();

        // Process proposal.
        bool passed = Kali(kali).processProposal(
            proposalId,
            call,
            ProposalType.CALL,
            "test"
        );
        assert(passed);

        // Check processed Dai balances.
        assertEq(mockDai.balanceOf(alice), 500_000_000 ether);
        assertEq(mockDai.balanceOf(bob), 500_000_000 ether);
        assertEq(mockDai.balanceOf(kali), 0);
    }

    function testVotingPeriodProposal() public payable {
        // Check initial voting period.
        assertEq(Kali(kali).votingPeriod(), 1 days);

        // Setup proposal.
        Call[] memory call = new Call[](1);

        call[0].op = Operation.call;
        call[0].to = address(0);
        call[0].value = 2 days;
        call[0].data = "";

        // Propose as alice.
        vm.prank(alice);
        (uint256 proposalId, ) = Kali(kali).propose(
            call,
            ProposalType.VPERIOD,
            "test"
        );
        vm.stopPrank();

        // Skip ahead in voting period.
        vm.warp(block.timestamp + 12 hours);

        // Vote as alice.
        vm.prank(alice);
        Kali(kali).vote(proposalId, true, "");
        vm.stopPrank();

        // Vote as bob.
        vm.prank(bob);
        Kali(kali).vote(proposalId, true, "");
        vm.stopPrank();

        // Process proposal.
        bool passed = Kali(kali).processProposal(
            proposalId,
            call,
            ProposalType.VPERIOD,
            "test"
        );
        assert(passed);

        // Check processed voting period.
        assertEq(Kali(kali).votingPeriod(), 2 days);
    }

    function testGracePeriodProposal() public payable {
        // Check initial grace period.
        assertEq(Kali(kali).gracePeriod(), 0);

        // Setup proposal.
        Call[] memory call = new Call[](1);

        call[0].op = Operation.call;
        call[0].to = address(0);
        call[0].value = 1 days;
        call[0].data = "";

        // Propose as alice.
        vm.prank(alice);
        (uint256 proposalId, ) = Kali(kali).propose(
            call,
            ProposalType.GPERIOD,
            "test"
        );
        vm.stopPrank();

        // Skip ahead in voting period.
        vm.warp(block.timestamp + 12 hours);

        // Vote as alice.
        vm.prank(alice);
        Kali(kali).vote(proposalId, true, "");
        vm.stopPrank();

        // Vote as bob.
        vm.prank(bob);
        Kali(kali).vote(proposalId, true, "");
        vm.stopPrank();

        // Process proposal.
        bool passed = Kali(kali).processProposal(
            proposalId,
            call,
            ProposalType.GPERIOD,
            "test"
        );
        assert(passed);

        // Check processed grace period.
        assertEq(Kali(kali).gracePeriod(), 1 days);
    }

    function testQuorumProposal() public payable {
        // Check initial quorum.
        assertEq(Kali(kali).quorum(), 20);

        // Setup proposal.
        Call[] memory call = new Call[](1);

        call[0].op = Operation.call;
        call[0].to = address(0);
        call[0].value = 69;
        call[0].data = "";

        // Propose as alice.
        vm.prank(alice);
        (uint256 proposalId, ) = Kali(kali).propose(
            call,
            ProposalType.QUORUM,
            "test"
        );
        vm.stopPrank();

        // Skip ahead in voting period.
        vm.warp(block.timestamp + 12 hours);

        // Vote as alice.
        vm.prank(alice);
        Kali(kali).vote(proposalId, true, "");
        vm.stopPrank();

        // Vote as bob.
        vm.prank(bob);
        Kali(kali).vote(proposalId, true, "");
        vm.stopPrank();

        // Process proposal.
        bool passed = Kali(kali).processProposal(
            proposalId,
            call,
            ProposalType.QUORUM,
            "test"
        );
        assert(passed);

        // Check processed quorum.
        assertEq(Kali(kali).quorum(), 69);
    }

    function testSupermajorityProposal() public payable {
        // Check initial supermajority.
        assertEq(Kali(kali).supermajority(), 52);

        // Setup proposal.
        Call[] memory call = new Call[](1);

        call[0].op = Operation.call;
        call[0].to = address(0);
        call[0].value = 88;
        call[0].data = "";

        // Propose as alice.
        vm.prank(alice);
        (uint256 proposalId, ) = Kali(kali).propose(
            call,
            ProposalType.SUPERMAJORITY,
            "test"
        );
        vm.stopPrank();

        // Skip ahead in voting period.
        vm.warp(block.timestamp + 12 hours);

        // Vote as alice.
        vm.prank(alice);
        Kali(kali).vote(proposalId, true, "");
        vm.stopPrank();

        // Vote as bob.
        vm.prank(bob);
        Kali(kali).vote(proposalId, true, "");
        vm.stopPrank();

        // Process proposal.
        bool passed = Kali(kali).processProposal(
            proposalId,
            call,
            ProposalType.SUPERMAJORITY,
            "test"
        );
        assert(passed);

        // Check processed supermajority.
        assertEq(Kali(kali).supermajority(), 88);
    }

    function testTypeProposal() public payable {
        // Check initial type settings.
        assert(
            Kali(kali).proposalVoteTypes(ProposalType.CALL) ==
                VoteType.SIMPLE_MAJORITY_QUORUM_REQUIRED
        );

        // Setup proposal.
        Call[] memory call = new Call[](2);

        call[0].op = Operation.call;
        call[0].to = address(0);
        call[0].value = 2;
        call[0].data = "";

        call[1].op = Operation.call;
        call[1].to = address(0);
        call[1].value = 2;
        call[1].data = "";

        // Propose as alice.
        vm.prank(alice);
        (uint256 proposalId, ) = Kali(kali).propose(
            call,
            ProposalType.TYPE,
            "test"
        );
        vm.stopPrank();

        // Skip ahead in voting period.
        vm.warp(block.timestamp + 12 hours);

        // Vote as alice.
        vm.prank(alice);
        Kali(kali).vote(proposalId, true, "");
        vm.stopPrank();

        // Vote as bob.
        vm.prank(bob);
        Kali(kali).vote(proposalId, true, "");
        vm.stopPrank();

        // Process proposal.
        bool passed = Kali(kali).processProposal(
            proposalId,
            call,
            ProposalType.TYPE,
            "test"
        );
        assert(passed);

        // Check processed type settings.
        assert(
            Kali(kali).proposalVoteTypes(ProposalType.CALL) ==
                VoteType.SUPERMAJORITY_QUORUM_REQUIRED
        );
    }

    function testPauseProposal() public payable {
        // Check initial pause settings.
        assert(!Keep(keep).transferable(0));

        // Setup proposal.
        Call[] memory call = new Call[](1);

        call[0].op = Operation.call;
        call[0].to = address(0);
        call[0].value = 2;
        call[0].data = "";

        // Propose as alice.
        vm.prank(alice);
        (uint256 proposalId, ) = Kali(kali).propose(
            call,
            ProposalType.PAUSE,
            "test"
        );
        vm.stopPrank();

        // Skip ahead in voting period.
        vm.warp(block.timestamp + 12 hours);

        // Vote as alice.
        vm.prank(alice);
        Kali(kali).vote(proposalId, true, "");
        vm.stopPrank();

        // Vote as bob.
        vm.prank(bob);
        Kali(kali).vote(proposalId, true, "");
        vm.stopPrank();

        // Process proposal.
        bool passed = Kali(kali).processProposal(
            proposalId,
            call,
            ProposalType.PAUSE,
            "test"
        );
        assert(passed);

        // Check initial pause settings.
        assert(Keep(keep).transferable(0));
    }

    function testDeleteProposal() public payable {
        // Setup proposal.
        Call[] memory call = new Call[](1);

        call[0].op = Operation.call;
        call[0].to = address(0);
        call[0].value = 0;
        call[0].data = "";

        // -- 1 -- //

        // Propose as alice.
        vm.prank(alice);
        (uint256 proposalId, ) = Kali(kali).propose(
            call,
            ProposalType.URI,
            "test"
        );
        vm.stopPrank();

        // Skip ahead in voting period.
        vm.warp(block.timestamp + 12 hours);

        // Vote as alice.
        vm.prank(alice);
        Kali(kali).vote(proposalId, true, "");
        vm.stopPrank();

        // Vote as bob.
        vm.prank(bob);
        Kali(kali).vote(proposalId, true, "");
        vm.stopPrank();

        // -- 2 -- //

        call[0].value = proposalId;

        // Propose as alice.
        vm.prank(alice);
        (proposalId, ) = Kali(kali).propose(call, ProposalType.ESCAPE, "test");
        vm.stopPrank();

        // Skip ahead in voting period.
        vm.warp(block.timestamp + 12 hours);

        // Vote as alice.
        vm.prank(alice);
        Kali(kali).vote(proposalId, true, "");
        vm.stopPrank();

        // Vote as bob.
        vm.prank(bob);
        Kali(kali).vote(proposalId, true, "");
        vm.stopPrank();

        // Check proposal status before deletion.
        (, , , uint40 creationTime, , ) = Kali(kali).proposals(proposalId - 1);
        assertEq(creationTime, block.timestamp - 1 days);

        // Process proposal.
        bool passed = Kali(kali).processProposal(
            proposalId,
            call,
            ProposalType.ESCAPE,
            "test"
        );
        assert(passed);

        // Check proposal deletion.
        (, , , creationTime, , ) = Kali(kali).proposals(proposalId - 1);
        assertEq(creationTime, 0);
    }

    function testURIProposal() public payable {
        // Check initial uri settings.
        assertEq(Kali(kali).daoURI(), "DAO");

        // Setup proposal.
        Call[] memory call = new Call[](1);

        call[0].op = Operation.call;
        call[0].to = address(0);
        call[0].value = 0;
        call[0].data = "";

        // Propose as alice.
        vm.prank(alice);
        (uint256 proposalId, ) = Kali(kali).propose(
            call,
            ProposalType.URI,
            "test"
        );
        vm.stopPrank();

        // Skip ahead in voting period.
        vm.warp(block.timestamp + 12 hours);

        // Vote as alice.
        vm.prank(alice);
        Kali(kali).vote(proposalId, true, "");
        vm.stopPrank();

        // Vote as bob.
        vm.prank(bob);
        Kali(kali).vote(proposalId, true, "");
        vm.stopPrank();

        // Process proposal.
        bool passed = Kali(kali).processProposal(
            proposalId,
            call,
            ProposalType.URI,
            "test"
        );
        assert(passed);

        // Check processed uri settings.
        assertEq(Kali(kali).daoURI(), "test");
    }

    /// -----------------------------------------------------------------------
    /// Kali Extension Tests
    /// -----------------------------------------------------------------------

    function testFailNotAuthorizedExtension() public payable {
        assert(!Kali(kali).extensions(alice));
        assertEq(alice.balance, 0);

        Call memory call;

        call.op = Operation.call;
        call.to = alice;
        call.value = 1 ether;
        call.data = "";

        vm.prank(alice);
        Kali(kali).relay(call);
        vm.stopPrank();

        assertEq(alice.balance, 0);
    }

    function testExtensionRelay() public payable {
        assert(!Kali(kali).extensions(alice));
        vm.prank(kali);
        Kali(kali).setExtension(alice, true);
        vm.stopPrank();
        assert(Kali(kali).extensions(alice));

        assertEq(alice.balance, 0);

        Call memory call;

        call.op = Operation.call;
        call.to = alice;
        call.value = 1 ether;
        call.data = "";

        vm.prank(alice);
        Kali(kali).relay(call);
        vm.stopPrank();

        assertEq(alice.balance, 1 ether);
    }

    function testExtensionMint() public payable {
        assert(!Kali(kali).extensions(alice));
        vm.prank(kali);
        Kali(kali).setExtension(alice, true);
        vm.stopPrank();
        assert(Kali(kali).extensions(alice));

        assertEq(Keep(keep).balanceOf(alice, 0), 1);

        vm.prank(alice);
        Kali(kali).mint(KeepTokenManager(keep), alice, 0, 1, "");
        vm.stopPrank();

        assertEq(Keep(keep).balanceOf(alice, 0), 2);
    }

    function testExtensionBurn() public payable {
        assert(!Kali(kali).extensions(alice));
        vm.prank(kali);
        Kali(kali).setExtension(alice, true);
        vm.stopPrank();
        assert(Kali(kali).extensions(alice));

        assertEq(Keep(keep).balanceOf(alice, 0), 1);

        vm.prank(alice);
        Kali(kali).burn(KeepTokenManager(keep), alice, 0, 1);
        vm.stopPrank();

        assertEq(Keep(keep).balanceOf(alice, 0), 0);
    }

    function testExtensionSetTransferability(bool on) public payable {
        assert(!Kali(kali).extensions(alice));
        vm.prank(kali);
        Kali(kali).setExtension(alice, true);
        vm.stopPrank();
        assert(Kali(kali).extensions(alice));

        assert(!Keep(keep).transferable(0));

        vm.prank(alice);
        Kali(kali).setTransferability(KeepTokenManager(keep), 0, on);
        vm.stopPrank();

        assertEq(Keep(keep).transferable(0), on);
    }

    function testExtensionSetExtension(
        address extension,
        bool on
    ) public payable {
        vm.prank(kali);
        Kali(kali).setExtension(alice, true);
        vm.stopPrank();
        assert(Kali(kali).extensions(alice));

        vm.prank(alice);
        Kali(kali).setExtension(extension, on);
        vm.stopPrank();

        assertEq(Kali(kali).extensions(extension), on);
    }

    function testExtensionSetURI(string calldata uri) public payable {
        assert(!Kali(kali).extensions(alice));
        vm.prank(kali);
        Kali(kali).setExtension(alice, true);
        vm.stopPrank();
        assert(Kali(kali).extensions(alice));

        vm.prank(alice);
        Kali(kali).setURI(uri);
        vm.stopPrank();

        assertEq(Kali(kali).daoURI(), uri);
    }

    function testExtensionDeleteProposal() public payable {
        vm.warp(block.timestamp + 1 days);

        // Setup proposal.
        Call[] memory call = new Call[](1);

        call[0].op = Operation.call;
        call[0].to = alice;
        call[0].value = 1 ether;
        call[0].data = "";

        // Propose as alice.
        vm.prank(alice);
        (uint256 proposalId, ) = Kali(kali).propose(
            call,
            ProposalType.CALL,
            "test"
        );
        vm.stopPrank();

        // Check proposal creation.
        (, , , uint40 creationTime, , ) = Kali(kali).proposals(proposalId);
        assertEq(creationTime, block.timestamp);

        assert(!Kali(kali).extensions(alice));
        vm.prank(kali);
        Kali(kali).setExtension(alice, true);
        vm.stopPrank();
        assert(Kali(kali).extensions(alice));

        // Delete.
        vm.prank(alice);
        Kali(kali).deleteProposal(1);
        vm.stopPrank();

        // Check proposal deletion.
        (, , , creationTime, , ) = Kali(kali).proposals(proposalId);
        assertEq(creationTime, 0);

        // Check proposal processed state.
        (bool didPass, bool processed) = Kali(kali).proposalStates(proposalId);
        assert(!didPass);
        assert(processed);

        // Propose as alice.
        vm.prank(alice);
        (proposalId, ) = Kali(kali).propose(call, ProposalType.CALL, "test");
        vm.stopPrank();

        // Check proposal creation.
        (, , , creationTime, , ) = Kali(kali).proposals(proposalId);
        assertEq(creationTime, block.timestamp);

        // Delete.
        vm.prank(kali);
        Kali(kali).deleteProposal(2);
        vm.stopPrank();

        // Check proposal deletion.
        (, , , creationTime, , ) = Kali(kali).proposals(proposalId);
        assertEq(creationTime, 0);

        // Attempt repeat delete.
        vm.prank(kali);
        vm.expectRevert(InvalidProposal.selector);
        Kali(kali).deleteProposal(2);
        vm.stopPrank();

        // Propose as alice.
        vm.prank(alice);
        (proposalId, ) = Kali(kali).propose(call, ProposalType.CALL, "test");
        vm.stopPrank();

        // Check proposal creation.
        (, , , creationTime, , ) = Kali(kali).proposals(proposalId);
        assertEq(creationTime, block.timestamp);

        // Delete.
        vm.prank(bob);
        vm.expectRevert(Unauthorized.selector);
        Kali(kali).deleteProposal(3);
        vm.stopPrank();

        // Check proposal maintenance.
        (, , , creationTime, , ) = Kali(kali).proposals(proposalId);
        assertEq(creationTime, block.timestamp);
    }

    function testExtensionUpdateGovSettings() public payable {
        assert(!Kali(kali).extensions(alice));
        vm.prank(kali);
        Kali(kali).setExtension(alice, true);
        vm.stopPrank();
        assert(Kali(kali).extensions(alice));

        uint256[2] memory setting;
        setting[0] = 1;
        setting[1] = 1;

        vm.prank(alice);
        Kali(kali).updateGovSettings(2 days, 1 days, 42, 69, setting);
        vm.stopPrank();

        assertEq(Kali(kali).votingPeriod(), 2 days);
        assertEq(Kali(kali).gracePeriod(), 1 days);
        assertEq(Kali(kali).quorum(), 42);
        assertEq(Kali(kali).supermajority(), 69);
        assert(
            Kali(kali).proposalVoteTypes(ProposalType.BURN) ==
                VoteType.SIMPLE_MAJORITY
        );
    }

    function testExtensionUpdateGovSettingsInvalid() public payable {
        assert(!Kali(kali).extensions(alice));
        vm.prank(kali);
        Kali(kali).setExtension(alice, true);
        vm.stopPrank();
        assert(Kali(kali).extensions(alice));

        uint256[2] memory setting;
        setting[0] = 1;
        setting[1] = 1;

        vm.prank(alice);
        Kali(kali).updateGovSettings(0, 1 days, 42, 69, setting);

        assertEq(Kali(kali).votingPeriod(), 1 days);

        vm.prank(alice);
        Kali(kali).updateGovSettings(366 days, 1 days, 42, 69, setting);

        assertEq(Kali(kali).votingPeriod(), 1 days);

        vm.prank(alice);
        Kali(kali).updateGovSettings(1 days, 366 days, 42, 69, setting);

        assertEq(Kali(kali).gracePeriod(), 1 days);

        vm.prank(alice);
        Kali(kali).updateGovSettings(366 days, 366 days, 101, 69, setting);

        assertEq(Kali(kali).quorum(), 42);

        vm.prank(alice);
        Kali(kali).updateGovSettings(366 days, 366 days, 101, 50, setting);

        assertEq(Kali(kali).supermajority(), 69);

        vm.prank(alice);
        Kali(kali).updateGovSettings(366 days, 366 days, 101, 101, setting);

        assertEq(Kali(kali).supermajority(), 69);

        setting[1] = 3;

        vm.prank(alice);
        Kali(kali).updateGovSettings(366 days, 366 days, 101, 101, setting);

        assert(
            Kali(kali).proposalVoteTypes(ProposalType.BURN) ==
                VoteType.SUPERMAJORITY
        );

        setting[0] = 100;
        setting[1] = 1;

        vm.prank(alice);
        Kali(kali).updateGovSettings(366 days, 366 days, 101, 101, setting);

        assert(
            Kali(kali).proposalVoteTypes(ProposalType.BURN) ==
                VoteType.SUPERMAJORITY
        );

        setting[0] = 1;
        setting[1] = 100;

        vm.prank(alice);
        Kali(kali).updateGovSettings(366 days, 366 days, 101, 101, setting);

        assert(
            Kali(kali).proposalVoteTypes(ProposalType.BURN) ==
                VoteType.SUPERMAJORITY
        );
    }
}
