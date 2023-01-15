// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @dev Keep core.
import {KeepToken, Operation, Call, Signature, Keep} from "../src/Keep.sol";
import {KeepFactory} from "../src/KeepFactory.sol";
import {URIFetcher} from "../src/extensions/metadata/URIFetcher.sol";
import {URIRemoteFetcher} from "../src/extensions/metadata/URIRemoteFetcher.sol";

/// @dev Kali core.
import {KeepTokenManager, Proposal, ProposalType, Kali} from "../src/extensions/dao/Kali.sol";
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

contract KaliTest is Test, Keep(Keep(address(0))) {
    address keepAddr;
    address kaliAddr;

    address keep;
    KeepFactory keepFactory;

    Kali kali;
    KaliFactory kaliFactory;

    MockERC20 internal mockDai;
    MockERC721 internal mockNFT;
    MockERC1155 internal mock1155;
    MockERC1271Wallet internal mockERC1271Wallet;
    MockUnsafeERC1155Receiver internal mockUnsafeERC1155Receiver;

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

        // Mint mock ERC20.
        mockDai.mint(address(this), 1_000_000_000 ether);
        // Mint mock 721.
        mockNFT.mint(address(this), 1);
        // Mint mock 1155.
        mock1155.mint(address(this), 1, 1, "");

        // Create the Keep templates.
        keep = address(new Keep(Keep(address(address(0)))));
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
        kali = new Kali();
        // Create the Kali factory.
        kaliFactory = new KaliFactory(kali);

        // Prime dummy inputs;
        Call[] memory dummyCall = new Call[](1);

        uint120[4] memory govSettings;
        govSettings[0] = 1 days;
        govSettings[1] = 0;
        govSettings[2] = 20;
        govSettings[3] = 52;

        kaliAddr = kaliFactory.determineKali(KeepTokenManager(keep), 0, name1);

        kali = Kali(kaliAddr);

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
        Keep(keep).mint(address(kali), CORE_KEY, 1, "");
        vm.stopPrank();

        assertEq(Keep(keep).balanceOf(address(kali), CORE_KEY), 1);

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

    /// @notice Check deployment.

    function testDetermination() public payable {
        // Check CREATE2 clones match expected outputs.
        address computedAddr = kaliFactory.determineKali(
            KeepTokenManager(keep),
            0,
            name1
        );

        assertEq(address(kali), computedAddr);
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
        assertEq(kali.name(), string(abi.encodePacked(name1)));
    }

    function testToken() public payable {
        assertEq(address(kali.token()), address(keep));
    }

    function testTokenId() public payable {
        assertEq(kali.tokenId(), 0);
    }

    function testDaoURI() public payable {
        assertEq(kali.daoURI(), "DAO");
    }

    function testVotingPeriod() public payable {
        assertEq(kali.votingPeriod(), 1 days);
    }

    function testGracePeriod() public payable {
        assertEq(kali.gracePeriod(), 0);
    }

    function testQuorum() public payable {
        assertEq(kali.quorum(), 20);
    }

    function testSupermajority() public payable {
        assertEq(kali.supermajority(), 52);
    }

    function testSupportsInterface() public payable {
        assert(kali.supportsInterface(0x01ffc9a7));
        assert(kali.supportsInterface(0x150b7a02));
        assert(kali.supportsInterface(0x4e2312e0));
    }

    /// -----------------------------------------------------------------------
    /// Kali Receiver Tests
    /// -----------------------------------------------------------------------

    function testERC20Receiver() public payable {
        mockDai.transfer(address(kali), 1 ether);
    }

    function testERC721Receiver() public payable {
        mockNFT.transferFrom(address(this), address(kali), 1);
    }

    function testERC1155Receiver() public payable {
        mock1155.safeTransferFrom(address(this), address(kali), 1, 1, "");
    }

    function testERC1155BatchReceiver() public payable {
        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 1;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1;
        amounts[1] = 0;

        mock1155.safeBatchTransferFrom(
            address(this),
            address(kali),
            ids,
            amounts,
            ""
        );
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
        uint256 proposalId = kali.propose(ProposalType.CALL, name1, call);
        vm.stopPrank();

        // Check proposal creation.
        (, , , uint40 creationTime, , ) = kali.proposals(proposalId);
        assertEq(creationTime, block.timestamp);
        assert(block.timestamp != 0);

        // Check proposal hash.
        (, bytes32 digest, , , , ) = kali.proposals(proposalId);
        bytes32 proposalHash = keccak256(
            abi.encode(ProposalType.CALL, name1, call)
        );
        assertEq(digest, proposalHash);
    }

    function testProposal() public payable {
        // Check initial ETH.
        assertEq(address(kali).balance, 10 ether);
        assertEq(alice.balance, 0 ether);

        // Setup proposal.
        Call[] memory call = new Call[](1);

        call[0].op = Operation.call;
        call[0].to = alice;
        call[0].value = 1 ether;
        call[0].data = "";

        // Propose as alice.
        vm.prank(alice);
        uint256 proposalId = kali.propose(ProposalType.CALL, name1, call);
        vm.stopPrank();

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
        (, , , , uint216 yesVotes, uint216 noVotes) = kali.proposals(
            proposalId
        );
        assertEq(yesVotes, 2);
        assertEq(noVotes, 0);

        // Process proposal.
        bool passed = kali.processProposal(
            proposalId,
            ProposalType.CALL,
            name1,
            call
        );
        assert(passed);

        // Check proposal state.
        (bool didPass, bool processed) = kali.proposalStates(proposalId);
        assert(didPass);
        assert(processed);

        // Check ETH was sent.
        assertEq(address(kali).balance, 9 ether);
        assertEq(alice.balance, 1 ether);
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
        uint256 proposalId = kali.propose(ProposalType.MINT, name1, call);
        vm.stopPrank();

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
        (, , , , uint216 yesVotes, uint216 noVotes) = kali.proposals(
            proposalId
        );
        assertEq(yesVotes, 2);
        assertEq(noVotes, 0);

        // Process proposal.
        bool passed = kali.processProposal(
            proposalId,
            ProposalType.MINT,
            name1,
            call
        );
        assert(passed);

        // Check proposal state.
        (bool didPass, bool processed) = kali.proposalStates(proposalId);
        assert(didPass);
        assert(processed);

        // Check processed alice DAO (0) balance.
        assertEq(Keep(keep).balanceOf(alice, 0), 2);
    }
}
