// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @dev Core.
import {KeepToken, Operation, Call, Signature, Keep} from "../src/Keep.sol";
import {KeepFactory} from "../src/KeepFactory.sol";

/// @dev Extensions.
import {URIFetcher} from "../src/extensions/metadata/URIFetcher.sol";

/// @dev Mocks.
import {MockERC20} from "@solbase/test/utils/mocks/MockERC20.sol";
import {MockERC721} from "@solbase/test/utils/mocks/MockERC721.sol";
import {MockERC1155} from "@solbase/test/utils/mocks/MockERC1155.sol";
import {MockERC1271Wallet} from "@solbase/test/utils/mocks/MockERC1271Wallet.sol";
import {MockUnsafeERC1155Receiver} from "./utils/mocks/MockUnsafeERC1155Receiver.sol";

/// @dev Test framework.
import "@std/Test.sol";

contract KeepTest is Keep(this), Test {
    /// -----------------------------------------------------------------------
    /// Keep Storage/Logic
    /// -----------------------------------------------------------------------

    using stdStorage for StdStorage;

    address internal keepAddr;
    address internal keepAddrRepeat;

    Keep internal keep;
    Keep internal keepRepeat;

    KeepFactory internal factory;

    URIFetcher internal mockUriFetcher;
    URIFetcher internal uriRemote;
    URIFetcher internal uriRemoteNew;

    MockERC20 internal mockDai;
    MockERC721 internal mockNFT;
    MockERC1155 internal mock1155;
    MockERC1271Wallet internal mockERC1271Wallet;
    MockUnsafeERC1155Receiver internal mockUnsafeERC1155Receiver;

    uint256 internal chainId;

    uint256 internal immutable SIGNER_KEY = uint32(keep.execute.selector);

    bytes32 internal constant name1 =
        0x5445535400000000000000000000000000000000000000000000000000000000;

    bytes32 internal constant name2 =
        0x5445535432000000000000000000000000000000000000000000000000000000;

    bytes32 internal constant PERMIT_TYPEHASH =
        keccak256(
            "Permit(address owner,address operator,bool approved,uint256 nonce,uint256 deadline)"
        );

    bytes32 internal constant DELEGATION_TYPEHASH =
        keccak256(
            "Delegation(address delegator,address delegatee,uint256 id,uint256 nonce,uint256 deadline)"
        );

    Call[] calls;

    address[] signers;

    /// @dev Mock Users.

    address internal alice;
    uint256 internal alicesPk;

    address internal bob;
    uint256 internal bobsPk;

    address internal charlie;
    uint256 internal charliesPk;

    address internal nully;
    uint256 internal nullPk;

    /// @dev Helpers.

    function computeDomainSeparator(address addr)
        internal
        view
        returns (bytes32)
    {
        return
            keccak256(
                abi.encode(
                    keccak256(
                        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                    ),
                    keccak256(bytes("Keep")),
                    keccak256("1"),
                    block.chainid,
                    addr
                )
            );
    }

    function getDigest(
        Operation op,
        address to,
        uint256 value,
        bytes memory data,
        uint120 nonce,
        bytes32 domainSeparator
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    domainSeparator,
                    keccak256(
                        abi.encode(
                            keccak256(
                                "Execute(uint8 op,address to,uint256 value,bytes data,uint120 nonce)"
                            ),
                            op,
                            to,
                            value,
                            keccak256(data),
                            nonce
                        )
                    )
                )
            );
    }

    function signExecution(
        address user,
        uint256 pk,
        Operation op,
        address to,
        uint256 value,
        bytes memory data
    ) internal view returns (Signature memory sig) {
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            pk,
            getDigest(
                op,
                to,
                value,
                data,
                0,
                computeDomainSeparator(address(keep))
            )
        );

        // Set 'wrong v' to return null signer for tests.
        if (pk == nullPk) {
            v = 17;
        }

        sig = Signature({user: user, v: v, r: r, s: s});
    }

    /// -----------------------------------------------------------------------
    /// Keep Setup Tests
    /// -----------------------------------------------------------------------

    /// @dev Set up the testing suite.

    function setUp() public payable {
        /// @dev Mock Users.

        (alice, alicesPk) = makeAddrAndKey("alice");

        (bob, bobsPk) = makeAddrAndKey("bob");

        (charlie, charliesPk) = makeAddrAndKey("charlie");

        (nully, nullPk) = makeAddrAndKey("null");

        // Initialize templates.
        mockUriFetcher = new URIFetcher();

        keep = new Keep(Keep(address(mockUriFetcher)));

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

        // Create the factory.
        factory = new KeepFactory(address(keep));

        // Create the Signer[] for setup.
        address[] memory setupSigners = new address[](2);
        setupSigners[0] = alice > bob ? bob : alice;
        setupSigners[1] = alice > bob ? alice : bob;

        // Store the signers for later.
        signers.push(alice > bob ? bob : alice);
        signers.push(alice > bob ? alice : bob);

        // Initialize Keep from factory.
        // The factory is fully tested in KeepFactory.t.sol.
        keepAddr = factory.determineKeep(name1);
        keep = Keep(keepAddr);

        factory.deployKeep(name1, calls, setupSigners, 2);

        // Mint mock smart wallet a signer ID key.
        vm.prank(address(keep));
        keep.mint(address(mockERC1271Wallet), SIGNER_KEY, 1, "");
        vm.stopPrank();

        // Store chainId.
        chainId = block.chainid;

        // Deposit ETH.
        (bool sent, ) = address(keep).call{value: 5 ether}("");
        assert(sent);

        // Deposit Dai.
        mockDai.transfer(address(keep), 100 ether);
    }

    /// @dev Check setup conditions.

    /*function testURISetup() public payable {
        assertEq(keep.uri(1), "");

        vm.prank(address(alice));
        uriRemote.setAlphaURI("ALPHA");
        vm.stopPrank();

        assertEq(keep.uri(0), "ALPHA");
        assertEq(keep.uri(1), "ALPHA");

        vm.prank(address(alice));
        uriRemote.setBetaURI(address(keep), "BETA");
        vm.stopPrank();

        assertEq(keep.uri(0), "BETA");
        assertEq(keep.uri(1), "BETA");

        vm.prank(address(alice));
        uriRemote.setURI(address(keep), 0, "CUSTOM");
        vm.stopPrank();

        assertEq(keep.uri(0), "CUSTOM");
        assertEq(keep.uri(1), "BETA");

        vm.prank(address(alice));
        uriRemote.setBetaURI(address(keep), "");
        vm.stopPrank();

        assertEq(keep.uri(0), "CUSTOM");
        assertEq(keep.uri(1), "ALPHA");

        vm.prank(address(alice));
        uriRemote.setAlphaURI("");
        vm.stopPrank();

        assertEq(keep.uri(0), "CUSTOM");
        assertEq(keep.uri(1), "");

        vm.prank(address(alice));
        uriRemote.setURI(address(keep), 0, "");
        vm.stopPrank();

        assertEq(keep.uri(0), "");
        assertEq(keep.uri(1), "");

        vm.prank(address(alice));
        mockUriFetcher.setURIRemoteFetcher(uriRemoteNew);
        vm.stopPrank();

        vm.prank(address(alice));
        vm.expectRevert(Unauthorized.selector);
        uriRemoteNew.setURI(address(keep), 0, "");
        vm.stopPrank();

        vm.prank(address(bob));
        uriRemoteNew.setURI(address(keep), 0, "NEW");
        vm.stopPrank();

        assertEq(keep.uri(0), "NEW");
        assertEq(keep.uri(1), "");
    }*/

    function testSignerSetup() public payable {
        // Check users.
        assert(keep.balanceOf(alice, SIGNER_KEY) == 1);
        assert(keep.balanceOf(bob, SIGNER_KEY) == 1);
        assert(keep.balanceOf(charlie, SIGNER_KEY) == 0);

        // Also check smart wallet.
        assert(keep.balanceOf(address(mockERC1271Wallet), SIGNER_KEY) == 1);

        // Check supply.
        assert(keep.totalSupply(SIGNER_KEY) == 3);
        assert(keep.totalSupply(42069) == 0);
    }

    /// @notice Check setup errors.

    function testCannotRepeatKeepSetup() public payable {
        keepRepeat = new Keep(Keep(address(mockUriFetcher)));

        keepAddrRepeat = factory.determineKeep(name2);
        keepRepeat = Keep(keepAddrRepeat);
        factory.deployKeep(name2, calls, signers, 2);

        vm.expectRevert(AlreadyInit.selector);
        keepRepeat.initialize(calls, signers, 2);
    }

    function testCannotSetupWithZeroQuorum() public payable {
        vm.expectRevert(InvalidThreshold.selector);
        factory.deployKeep(name2, calls, signers, 0);
    }

    function testCannotSetupWithExcessiveQuorum() public payable {
        vm.expectRevert(QuorumOverSupply.selector);
        factory.deployKeep(name2, calls, signers, 3);
    }

    function testCannotSetupWithOutOfOrderSigners() public payable {
        address[] memory outOfOrderSigners = new address[](2);
        outOfOrderSigners[0] = alice > bob ? alice : bob;
        outOfOrderSigners[1] = alice > bob ? bob : alice;

        vm.expectRevert(InvalidSig.selector);
        factory.deployKeep(name2, calls, outOfOrderSigners, 2);
    }

    /// -----------------------------------------------------------------------
    /// Keep State Tests
    /// -----------------------------------------------------------------------

    function testName() public {
        assertEq(keep.name(), string(abi.encodePacked(name1)));
    }

    function testKeepNonce() public view {
        assert(keep.nonce() == 0);
    }

    function testUserNonce() public view {
        assert(keep.nonces(alice) == 0);
    }

    function testQuorum() public payable {
        assert(keep.quorum() == 2);

        vm.prank(address(keep));
        keep.setQuorum(3);
        vm.stopPrank();

        assert(keep.quorum() == 3);
    }

    function testBalanceOf() public {
        assert(keep.balanceOf(alice, 0) == 0);

        vm.prank(address(keep));
        keep.mint(alice, 0, 1, "");
        vm.stopPrank();

        assert(keep.balanceOf(alice, 0) == 1);
    }

    function testBalanceOfSigner() public {
        assert(keep.balanceOf(charlie, SIGNER_KEY) == 0);

        vm.prank(address(keep));
        keep.mint(charlie, SIGNER_KEY, 1, "");
        vm.stopPrank();

        assert(keep.balanceOf(charlie, SIGNER_KEY) == 1);
    }

    function testBalanceOfBatch() public {
        address[] memory owners = new address[](2);
        owners[0] = alice;
        owners[1] = bob;

        uint256[] memory ids = new uint256[](2);
        ids[0] = 0;
        ids[1] = SIGNER_KEY;

        uint256[] memory balances = new uint256[](2);
        balances = keep.balanceOfBatch(owners, ids);

        assert(balances[0] == 0);
        assert(balances[1] == 1);

        vm.prank(address(keep));
        keep.mint(alice, 0, 1, "");
        vm.stopPrank();

        balances = keep.balanceOfBatch(owners, ids);

        assert(balances[0] == 1);
        assert(balances[1] == 1);
    }

    function testCannotFetchMismatchedLengthBalanceOfBatch() public {
        address[] memory owners = new address[](2);
        owners[0] = alice;
        owners[1] = bob;

        uint256[] memory ids = new uint256[](1);
        ids[0] = 0;

        uint256[] memory balances = new uint256[](2);
        vm.expectRevert(LengthMismatch.selector);
        balances = keep.balanceOfBatch(owners, ids);
    }

    function testTotalSupply() public {
        assert(keep.totalSupply(0) == 0);

        vm.prank(address(keep));
        keep.mint(alice, 0, 1, "");
        vm.stopPrank();

        assert(keep.totalSupply(0) == 1);
    }

    function testTotalSignerSupply() public {
        assert(keep.totalSupply(SIGNER_KEY) == 3);

        vm.prank(address(keep));
        keep.mint(charlie, SIGNER_KEY, 1, "");
        vm.stopPrank();

        assert(keep.totalSupply(SIGNER_KEY) == 4);
    }

    function testSupportsInterface() public {
        assertTrue(keep.supportsInterface(0x150b7a02));
        assertTrue(keep.supportsInterface(0x4e2312e0));
        assertTrue(keep.supportsInterface(0x01ffc9a7));
        assertTrue(keep.supportsInterface(0xd9b67a26));
        assertTrue(keep.supportsInterface(0x0e89341c));
    }

    function testNoKeepKeyCollision() public view {
        assert(
            keep.multirelay.selector != keep.mint.selector &&
                keep.mint.selector != keep.burn.selector &&
                keep.burn.selector != keep.setQuorum.selector &&
                keep.setQuorum.selector != keep.setTransferability.selector &&
                keep.setTransferability.selector !=
                keep.setPermission.selector &&
                keep.setPermission.selector !=
                keep.setUserPermission.selector &&
                keep.setUserPermission.selector != keep.setURI.selector
        );
    }

    /// -----------------------------------------------------------------------
    /// Keep Operations Tests
    /// -----------------------------------------------------------------------

    /// @dev Check receivers.

    function testReceiveETH() public payable {
        (bool sent, ) = address(keep).call{value: 5 ether}("");
        assert(sent);
        // We check addition to setup balance.
        assert(address(keep).balance == 10 ether);
    }

    function testReceiveERC721() public payable {
        mockNFT.safeTransferFrom(address(this), address(keep), 1);
        assert(mockNFT.ownerOf(1) == address(keep));
    }

    function testReceiveERC1155() public payable {
        mock1155.safeTransferFrom(address(this), address(keep), 1, 1, "");
        assert(mock1155.balanceOf(address(keep), 1) == 1);
    }

    function testReceiveBatchERC1155() public payable {
        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        mock1155.safeBatchTransferFrom(
            address(this),
            address(keep),
            ids,
            amounts,
            ""
        );
        assert(mock1155.balanceOf(address(keep), 1) == 1);
    }

    function testReceiveKeepERC1155() public payable {
        address local = address(this);

        startHoax(address(keep), address(keep), type(uint256).max);
        keep.mint(local, 2, 1, "");
        keep.setTransferability(2, true);
        vm.stopPrank();

        keep.safeTransferFrom(local, address(keep), 2, 1, "");
        assert(keep.balanceOf(address(keep), 2) == 1);
    }

    function testReceiveBatchKeepERC1155() public payable {
        address local = address(this);

        startHoax(address(keep), address(keep), type(uint256).max);
        keep.mint(local, 2, 1, "");
        keep.setTransferability(2, true);
        vm.stopPrank();

        uint256[] memory ids = new uint256[](1);
        ids[0] = 2;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        keep.safeBatchTransferFrom(local, address(keep), ids, amounts, "");
        assert(keep.balanceOf(address(keep), 2) == 1);
    }

    /// @dev Check call execution.

    function testExecuteTokenCallWithRole() public payable {
        // Mint executor role.
        vm.prank(address(keep));
        keep.mint(alice, uint32(keep.multirelay.selector), 1, "");

        // Mock execution.
        bytes memory data = abi.encodeCall(mockDai.transfer, (alice, 100));

        Call[] memory call = new Call[](1);

        call[0].op = Operation.call;
        call[0].to = address(mockDai);
        call[0].value = 0;
        call[0].data = data;

        uint256 balanceBefore = mockDai.balanceOf(alice);

        vm.prank(alice);
        keep.multirelay(call);

        assert(mockDai.balanceOf(alice) == balanceBefore + 100);
    }

    function testExecuteTokenCallWithSignatures() public payable {
        bytes memory tx_data = abi.encodeCall(mockDai.transfer, (alice, 100));

        Signature[] memory sigs = new Signature[](2);

        Signature memory aliceSig = signExecution(
            alice,
            alicesPk,
            Operation.call,
            address(mockDai),
            0,
            tx_data
        );

        Signature memory bobSig = signExecution(
            bob,
            bobsPk,
            Operation.call,
            address(mockDai),
            0,
            tx_data
        );

        sigs[0] = bobSig;
        sigs[1] = aliceSig;

        // Execute tx.
        keep.execute(Operation.call, address(mockDai), 0, tx_data, sigs);
    }

    function testExecuteTokenCallWithContractSignatures() public payable {
        bytes memory tx_data = abi.encodeCall(mockDai.transfer, (alice, 100));

        Signature[] memory sigs = new Signature[](2);

        Signature memory aliceSig;
        Signature memory bobSig;

        aliceSig = signExecution(
            address(mockERC1271Wallet),
            alicesPk,
            Operation.call,
            address(mockDai),
            0,
            tx_data
        );

        bobSig = signExecution(
            bob,
            bobsPk,
            Operation.call,
            address(mockDai),
            0,
            tx_data
        );

        sigs[0] = aliceSig;
        sigs[1] = bobSig;

        // Execute tx.
        keep.execute(Operation.call, address(mockDai), 0, tx_data, sigs);
    }

    function testExecuteEthCall() public payable {
        Signature[] memory sigs = new Signature[](2);

        Signature memory aliceSig;
        Signature memory bobSig;

        aliceSig = signExecution(
            alice,
            alicesPk,
            Operation.call,
            alice,
            1 ether,
            ""
        );

        bobSig = signExecution(bob, bobsPk, Operation.call, alice, 1 ether, "");

        sigs[0] = bobSig;
        sigs[1] = aliceSig;

        // Execute tx.
        keep.execute(Operation.call, alice, 1 ether, "", sigs);
    }

    function testNonceIncrementAfterExecute() public payable {
        assert(keep.nonce() == 0);

        Signature[] memory sigs = new Signature[](2);

        Signature memory aliceSig;
        Signature memory bobSig;

        aliceSig = signExecution(
            alice,
            alicesPk,
            Operation.call,
            alice,
            1 ether,
            ""
        );

        bobSig = signExecution(bob, bobsPk, Operation.call, alice, 1 ether, "");

        sigs[0] = bobSig;
        sigs[1] = aliceSig;

        // Execute tx.
        keep.execute(Operation.call, alice, 1 ether, "", sigs);

        // Confirm nonce increment.
        assert(keep.nonce() == 1);

        // Confirm revert for stale nonce.
        vm.expectRevert(InvalidSig.selector);
        keep.execute(Operation.call, alice, 1 ether, "", sigs);
    }

    function testExecuteDelegateCall() public payable {
        bytes memory tx_data;

        address a = alice;

        assembly {
            mstore(add(tx_data, 0x20), shl(0xE0, 0x70a08231)) // `balanceOf(address)`.
            mstore(add(tx_data, 0x24), a)
            mstore(tx_data, 0x24)
            // Update free memory pointer.
            mstore(0x40, add(tx_data, 0x60))
        }

        Signature[] memory sigs = new Signature[](2);

        Signature memory aliceSig;
        Signature memory bobSig;

        aliceSig = signExecution(
            alice,
            alicesPk,
            Operation.delegatecall,
            address(mockDai),
            0,
            tx_data
        );

        bobSig = signExecution(
            bob,
            bobsPk,
            Operation.delegatecall,
            address(mockDai),
            0,
            tx_data
        );

        sigs[0] = bobSig;
        sigs[1] = aliceSig;

        // Execute tx.
        keep.execute(
            Operation.delegatecall,
            address(mockDai),
            0,
            tx_data,
            sigs
        );
    }

    function testExecuteCreateCall() public payable {
        bytes memory tx_data = type(MockERC1155).creationCode;

        Signature[] memory sigs = new Signature[](2);

        Signature memory aliceSig = signExecution(
            alice,
            alicesPk,
            Operation.create,
            address(0),
            0,
            tx_data
        );

        Signature memory bobSig = signExecution(
            bob,
            bobsPk,
            Operation.create,
            address(0),
            0,
            tx_data
        );

        sigs[0] = bobSig;
        sigs[1] = aliceSig;

        // Execute tx.
        keep.execute(Operation.create, address(0), 0, tx_data, sigs);
    }

    /// @dev Check execution errors.

    function testCannotExecuteWithImproperSignatures() public payable {
        bytes memory tx_data = abi.encodeCall(mockDai.transfer, (alice, 100));

        Signature[] memory sigs = new Signature[](2);

        Signature memory aliceSig;
        Signature memory charlieSig;

        aliceSig = signExecution(
            alice,
            alicesPk,
            Operation.call,
            address(mockDai),
            0,
            tx_data
        );

        charlieSig = signExecution(
            bob,
            charliesPk,
            Operation.call,
            address(mockDai),
            0,
            tx_data
        );

        sigs[0] = alice > charlie ? charlieSig : aliceSig;
        sigs[1] = alice > charlie ? aliceSig : charlieSig;

        // Execute tx.
        vm.expectRevert(InvalidSig.selector);
        keep.execute(Operation.call, address(mockDai), 0, tx_data, sigs);
    }

    function testCannotExecuteWithSignaturesOutOfOrder() public payable {
        bytes memory tx_data = abi.encodeCall(mockDai.transfer, (alice, 100));

        Signature[] memory sigs = new Signature[](2);

        Signature memory aliceSig;
        Signature memory bobSig;

        aliceSig = signExecution(
            alice,
            alicesPk,
            Operation.call,
            address(mockDai),
            0,
            tx_data
        );

        bobSig = signExecution(
            bob,
            bobsPk,
            Operation.call,
            address(mockDai),
            0,
            tx_data
        );

        sigs[0] = alice > bob ? aliceSig : bobSig;
        sigs[1] = alice > bob ? bobSig : aliceSig;

        // Execute tx.
        vm.expectRevert(InvalidSig.selector);
        keep.execute(Operation.call, address(mockDai), 0, tx_data, sigs);
    }

    function testCannotExecuteWithSignaturesRepeated() public payable {
        bytes memory tx_data = abi.encodeCall(mockDai.transfer, (alice, 100));

        Signature[] memory sigs = new Signature[](2);

        Signature memory aliceSig;

        aliceSig = signExecution(
            alice,
            alicesPk,
            Operation.call,
            address(mockDai),
            0,
            tx_data
        );

        sigs[0] = aliceSig;
        sigs[1] = aliceSig;

        // Execute tx.
        vm.expectRevert(InvalidSig.selector);
        keep.execute(Operation.call, address(mockDai), 0, tx_data, sigs);
    }

    function testCannotExecuteWithNullSignatures() public payable {
        bytes memory tx_data = abi.encodeCall(mockDai.transfer, (alice, 100));

        Signature[] memory sigs = new Signature[](2);

        Signature memory aliceSig;
        Signature memory nullSig;

        aliceSig = signExecution(
            alice,
            alicesPk,
            Operation.call,
            address(mockDai),
            0,
            tx_data
        );

        nullSig = signExecution(
            nully,
            nullPk,
            Operation.call,
            address(mockDai),
            0,
            tx_data
        );

        sigs[0] = alice > nully ? nullSig : aliceSig;
        sigs[1] = alice > nully ? aliceSig : nullSig;

        // Execute tx.
        vm.expectRevert(InvalidSig.selector);
        keep.execute(Operation.call, address(mockDai), 0, tx_data, sigs);
    }

    /// -----------------------------------------------------------------------
    /// Keep Governance Tests
    /// -----------------------------------------------------------------------

    function testMint(
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) public payable {
        vm.assume(id != SIGNER_KEY);
        vm.assume(id != uint32(type(KeepToken).interfaceId)); // CORE_KEY
        vm.assume(keep.totalSupply(uint32(type(KeepToken).interfaceId)) == 0);
        amount = bound(amount, 0, type(uint216).max);

        uint256 preTotalSupply = keep.totalSupply(id);
        uint256 preBalance = keep.balanceOf(charlie, id);

        vm.prank(address(keep));
        keep.mint(charlie, id, amount, data);
        vm.stopPrank();

        assert(keep.balanceOf(charlie, id) == preBalance + amount);
        assert(keep.totalSupply(id) == preTotalSupply + amount);
    }

    function testMintExecuteIdKey() public payable {
        uint256 executeTotalSupply = keep.totalSupply(SIGNER_KEY);
        uint256 executeBalance = keep.balanceOf(charlie, SIGNER_KEY);
        uint256 preQuorum = keep.quorum();

        vm.prank(address(keep));
        keep.mint(charlie, SIGNER_KEY, 1, "");
        vm.stopPrank();

        assert(keep.balanceOf(charlie, SIGNER_KEY) == executeBalance + 1);
        assert(keep.totalSupply(SIGNER_KEY) == executeTotalSupply + 1);
        assert(keep.quorum() == preQuorum);
    }

    function testMintCoreIdKey(uint256 amount) public payable {
        amount = bound(amount, 0, type(uint216).max);

        uint256 CORE_KEY = uint32(type(KeepToken).interfaceId);
        uint256 totalSupply = keep.totalSupply(CORE_KEY);
        uint256 balance = keep.balanceOf(charlie, CORE_KEY);
        uint256 preQuorum = keep.quorum();

        vm.prank(address(keep));
        keep.mint(charlie, CORE_KEY, amount, "");
        vm.stopPrank();

        assert(keep.balanceOf(charlie, CORE_KEY) == balance + amount);
        assert(keep.totalSupply(CORE_KEY) == totalSupply + amount);
        assert(keep.quorum() == preQuorum);
        assert(keep.totalSupply(CORE_KEY) == totalSupply + amount);
    }

    function testCannotMintToZeroAddress() public payable {
        assert(keep.totalSupply(SIGNER_KEY) == 3);

        startHoax(address(keep), address(keep), type(uint256).max);
        vm.expectRevert(InvalidRecipient.selector);
        keep.mint(address(0), SIGNER_KEY, 1, "");
        vm.expectRevert(InvalidRecipient.selector);
        keep.mint(address(0), 1, 1, "");
        vm.stopPrank();

        assert(keep.balanceOf(address(0), SIGNER_KEY) == 0);
        assert(keep.balanceOf(address(0), 1) == 0);

        assert(keep.totalSupply(SIGNER_KEY) == 3);
        assert(keep.totalSupply(1) == 0);

        assert(keep.quorum() == 2);
    }

    function testCannotMintToUnsafeAddress() public payable {
        assert(keep.totalSupply(SIGNER_KEY) == 3);

        startHoax(address(keep), address(keep), type(uint256).max);

        vm.expectRevert();
        keep.mint(address(mockDai), SIGNER_KEY, 1, "");

        vm.expectRevert(UnsafeRecipient.selector);
        keep.mint(address(mockUnsafeERC1155Receiver), SIGNER_KEY, 1, "");

        vm.expectRevert();
        keep.mint(address(mockDai), 1, 1, "");

        vm.expectRevert(UnsafeRecipient.selector);
        keep.mint(address(mockUnsafeERC1155Receiver), 1, 1, "");

        vm.stopPrank();

        assert(keep.balanceOf(address(0), SIGNER_KEY) == 0);
        assert(keep.balanceOf(address(0), 1) == 0);

        assert(keep.totalSupply(SIGNER_KEY) == 3);
        assert(keep.totalSupply(1) == 0);

        assert(keep.quorum() == 2);
    }

    function testCannotMintOverflowSupply() public payable {
        uint256 amount = 1 << 216;

        startHoax(address(keep), address(keep), type(uint256).max);

        keep.mint(charlie, 0, type(uint96).max, "");

        vm.expectRevert(Overflow.selector);
        keep.mint(charlie, 1, type(uint256).max, "");

        keep.mint(charlie, 2, type(uint216).max, "");

        vm.expectRevert(Overflow.selector);
        keep.mint(charlie, 2, 1, "");

        vm.expectRevert(Overflow.selector);
        keep.mint(charlie, 3, amount, "");

        vm.stopPrank();
    }

    function testCannotMintOverflowExecuteID() public payable {
        startHoax(address(keep), address(keep), type(uint256).max);

        keep.mint(charlie, SIGNER_KEY, 1, "");

        vm.expectRevert(Overflow.selector);
        keep.mint(charlie, SIGNER_KEY, 1, "");

        keep.burn(charlie, SIGNER_KEY, 1);

        keep.mint(charlie, SIGNER_KEY, 1, "");

        vm.expectRevert(Overflow.selector);
        keep.mint(charlie, SIGNER_KEY, 1, "");

        vm.stopPrank();
    }

    function testBurn() public payable {
        startHoax(address(keep), address(keep), type(uint256).max);
        keep.mint(alice, 1, 2, "");
        keep.burn(alice, 1, 1);
        vm.stopPrank();

        assert(keep.balanceOf(alice, 1) == 1);
        assert(keep.totalSupply(1) == 1);
    }

    function testBurnSigner() public payable {
        vm.prank(address(keep));
        keep.burn(alice, SIGNER_KEY, 1);
        vm.stopPrank();

        assert(keep.balanceOf(alice, SIGNER_KEY) == 0);
        assert(keep.totalSupply(SIGNER_KEY) == 2);
    }

    function testCannotBurnUnderflow() public payable {
        startHoax(address(keep), address(keep), type(uint256).max);
        keep.mint(alice, 1, 1, "");
        vm.expectRevert(stdError.arithmeticError);
        keep.burn(alice, 1, 2);
        vm.stopPrank();
    }

    function testIdKeyRole() public payable {
        vm.prank(charlie);
        vm.expectRevert(Unauthorized.selector);
        keep.mint(alice, 1, 100, "");

        vm.prank(address(keep));
        keep.mint(charlie, uint32(keep.mint.selector), 1, "");

        vm.prank(charlie);
        keep.mint(alice, 1, 100, "");

        assert(keep.balanceOf(alice, 1) == 100);
    }

    function testSetTransferability() public payable {
        startHoax(address(keep), address(keep), type(uint256).max);
        keep.setTransferability(1, true);
        keep.mint(charlie, 1, 1, "");
        vm.stopPrank();

        assertTrue(keep.transferable(1));

        vm.prank(charlie);
        keep.safeTransferFrom(charlie, alice, 1, 1, "");
        vm.stopPrank();

        vm.prank(address(keep));
        keep.setTransferability(1, false);
        vm.stopPrank();

        assertFalse(keep.transferable(1));
        assert(keep.balanceOf(alice, 1) == 1);

        vm.prank(alice);
        vm.expectRevert(NonTransferable.selector);
        keep.safeTransferFrom(alice, charlie, 1, 1, "");
        vm.stopPrank();
    }

    function testCannotSetTransferability(address user, uint256 id)
        public
        payable
    {
        vm.assume(user != address(keep));

        vm.prank(user);
        vm.expectRevert(Unauthorized.selector);
        keep.setTransferability(id, true);
        vm.stopPrank();

        assertFalse(keep.transferable(id));
    }

    function testSetURI(address user) public payable {
        vm.assume(user != address(keep));

        vm.prank(user);
        vm.expectRevert(Unauthorized.selector);
        keep.setURI(0, "TEST");
        vm.stopPrank();

        // The Keep itself should be able to update uri.
        vm.prank(address(keep));
        keep.setURI(0, "TEST");
        vm.stopPrank();

        assertEq(keccak256(bytes("TEST")), keccak256(bytes(keep.uri(0))));
    }

    /// -----------------------------------------------------------------------
    /// Keep Token Tests
    /// -----------------------------------------------------------------------

    function testKeepTokenApprove(address userA, address userB) public payable {
        vm.prank(userA);
        keep.setApprovalForAll(userB, true);
        vm.stopPrank();

        assertTrue(keep.isApprovedForAll(userA, userB));

        vm.prank(userA);
        keep.setApprovalForAll(userB, false);
        vm.stopPrank();

        assertFalse(keep.isApprovedForAll(userA, userB));
    }

    function testKeepTokenTransferByOwner(
        address userA,
        address userB,
        uint256 id,
        uint256 amount
    ) public payable {
        vm.assume(userA != userB);
        vm.assume(userA.code.length == 0);
        vm.assume(userB.code.length == 0);
        vm.assume(userA != address(0));
        vm.assume(userB != address(0));

        amount = bound(amount, 0, type(uint216).max);
        if (
            id == SIGNER_KEY &&
            (keep.balanceOf(userA, id) != 0 || keep.balanceOf(userB, id) != 0)
        ) {
            amount = amount - 1;
        }

        vm.startPrank(address(keep));
        keep.setTransferability(id, true);
        keep.mint(userA, id, amount, "");
        vm.stopPrank();

        uint256 userApreBalance = keep.balanceOf(userA, id);
        uint256 userBpreBalance = keep.balanceOf(userB, id);

        vm.prank(userA);
        keep.safeTransferFrom(userA, userB, id, amount, "");
        vm.stopPrank();

        assert(keep.balanceOf(userA, id) == userApreBalance - amount);
        assert(keep.balanceOf(userB, id) == userBpreBalance + amount);
    }

    function testKeepTokenTransferByOperator(
        address userA,
        address userB,
        address userC,
        uint256 id,
        uint256 amount
    ) public payable {
        vm.assume(userA != userB);
        vm.assume(userA.code.length == 0);
        vm.assume(userB.code.length == 0);
        vm.assume(userA != address(0));
        vm.assume(userB != address(0));

        amount = bound(amount, 0, type(uint216).max);
        if (
            id == SIGNER_KEY &&
            (keep.balanceOf(userA, id) != 0 || keep.balanceOf(userB, id) != 0)
        ) {
            amount = amount - 1;
        }

        startHoax(address(keep), address(keep), type(uint256).max);
        keep.setTransferability(id, true);
        keep.mint(userA, id, amount, "");
        vm.stopPrank();

        uint256 userApreBalance = keep.balanceOf(userA, id);
        uint256 userBpreBalance = keep.balanceOf(userB, id);

        vm.prank(userA);
        keep.setApprovalForAll(userC, true);
        vm.stopPrank();

        assertTrue(keep.isApprovedForAll(userA, userC));

        vm.prank(userC);
        keep.safeTransferFrom(userA, userB, id, amount, "");
        vm.stopPrank();

        assert(keep.balanceOf(userA, id) == userApreBalance - amount);
        assert(keep.balanceOf(userB, id) == userBpreBalance + amount);
    }

    function testCannotTransferKeepTokenAsUnauthorizedNonOwner(
        address userA,
        address userB,
        uint256 id,
        uint256 amount
    ) public payable {
        vm.assume(userA != userB);
        vm.assume(userA.code.length == 0);
        vm.assume(userB.code.length == 0);
        vm.assume(userA != address(0));
        vm.assume(userB != address(0));

        amount = bound(amount, 0, type(uint216).max);
        if (
            id == SIGNER_KEY &&
            (keep.balanceOf(userA, id) != 0 || keep.balanceOf(userB, id) != 0)
        ) {
            amount = amount - 1;
        }

        vm.startPrank(address(keep));
        keep.setTransferability(id, true);
        keep.mint(userA, id, amount, "");
        vm.stopPrank();

        vm.prank(userB);
        vm.expectRevert(Unauthorized.selector);
        keep.safeTransferFrom(userA, userB, id, amount, "");
        vm.stopPrank();
    }

    function testKeepTokenBatchTransferByOwner() public payable {
        startHoax(address(keep), address(keep), type(uint256).max);
        keep.setTransferability(0, true);
        keep.setTransferability(1, true);
        vm.stopPrank();

        assertTrue(keep.transferable(0));
        assertTrue(keep.transferable(1));

        startHoax(address(keep), address(keep), type(uint256).max);
        keep.mint(charlie, 0, 1, "");
        keep.mint(charlie, 1, 2, "");
        vm.stopPrank();

        uint256[] memory ids = new uint256[](2);
        ids[0] = 0;
        ids[1] = 1;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1;
        amounts[1] = 1;

        startHoax(charlie, charlie, type(uint256).max);
        keep.safeBatchTransferFrom(charlie, bob, ids, amounts, "");
        vm.stopPrank();

        assert(keep.balanceOf(charlie, 0) == 0);
        assert(keep.balanceOf(charlie, 1) == 1);
        assert(keep.balanceOf(bob, 0) == 1);
        assert(keep.balanceOf(bob, 1) == 1);
    }

    function testKeepTokenBatchTransferByOperator() public payable {
        startHoax(address(keep), address(keep), type(uint256).max);
        keep.setTransferability(0, true);
        keep.setTransferability(1, true);
        vm.stopPrank();

        assertTrue(keep.transferable(0));
        assertTrue(keep.transferable(1));

        startHoax(charlie, charlie, type(uint256).max);
        keep.setApprovalForAll(alice, true);
        vm.stopPrank();

        assertTrue(keep.isApprovedForAll(charlie, alice));

        startHoax(address(keep), address(keep), type(uint256).max);
        keep.mint(charlie, 0, 1, "");
        keep.mint(charlie, 1, 2, "");
        vm.stopPrank();

        uint256[] memory ids = new uint256[](2);
        ids[0] = 0;
        ids[1] = 1;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1;
        amounts[1] = 1;

        startHoax(alice, alice, type(uint256).max);
        keep.safeBatchTransferFrom(charlie, bob, ids, amounts, "");
        vm.stopPrank();

        assert(keep.balanceOf(charlie, 0) == 0);
        assert(keep.balanceOf(charlie, 1) == 1);
        assert(keep.balanceOf(bob, 0) == 1);
        assert(keep.balanceOf(bob, 1) == 1);
    }

    function testKeepTokenTransferPermission(
        address userA,
        address userB,
        address userC,
        uint256 id,
        uint256 amount
    ) public payable {
        vm.assume(userA != address(0));
        vm.assume(userB != address(0));
        vm.assume(userC != address(0));
        vm.assume(userA != userB);
        vm.assume(userB != userC);
        vm.assume(userA != userC);
        vm.assume(userA.code.length == 0);
        vm.assume(userB.code.length == 0);
        vm.assume(userC.code.length == 0);
        vm.assume(id != SIGNER_KEY);
        vm.assume(id != CORE_KEY);

        amount = bound(amount, 0, type(uint216).max);

        uint256 preBalanceA = keep.balanceOf(userA, id);
        uint256 preBalanceB = keep.balanceOf(userB, id);
        uint256 preBalanceC = keep.balanceOf(userC, id);

        startHoax(address(keep), address(keep), type(uint256).max);

        keep.setTransferability(id, true);

        keep.setPermission(id, true);

        keep.setUserPermission(userA, id, true);
        keep.setUserPermission(userB, id, true);

        keep.mint(userA, id, amount, "");

        vm.stopPrank();

        assertTrue(keep.transferable(id));
        assertTrue(keep.permissioned(id));

        assertTrue(keep.userPermissioned(userA, id));
        assertTrue(keep.userPermissioned(userB, id));
        assertFalse(keep.userPermissioned(userC, id));

        assert(keep.balanceOf(userA, id) == preBalanceA + amount);

        vm.prank(userA);
        keep.safeTransferFrom(userA, userB, id, amount, "");
        vm.stopPrank();

        assert(keep.balanceOf(userA, id) == preBalanceA);
        assert(keep.balanceOf(userB, id) == preBalanceB + amount);

        vm.prank(userB);
        keep.setApprovalForAll(userC, true);
        vm.stopPrank();

        assertTrue(keep.isApprovedForAll(userB, userC));

        vm.prank(userC);
        vm.expectRevert(NotPermitted.selector);
        keep.safeTransferFrom(userB, userC, id, amount, ""); // C not permissioned
        vm.stopPrank();

        assert(keep.balanceOf(userA, id) == preBalanceA);
        assert(keep.balanceOf(userB, id) == preBalanceB + amount);
        assert(keep.balanceOf(userC, id) == preBalanceC);

        vm.prank(address(keep));
        keep.setUserPermission(userC, id, true);
        vm.stopPrank();

        assertTrue(keep.userPermissioned(userC, id));

        vm.prank(userC);
        keep.safeTransferFrom(userB, userC, id, amount, "");
        vm.stopPrank();

        assert(keep.balanceOf(userB, id) == preBalanceB);
        assert(keep.balanceOf(userC, id) == preBalanceC + amount);

        vm.prank(address(keep));
        keep.setTransferability(id, false);
        vm.stopPrank();

        assertFalse(keep.transferable(id));

        vm.prank(userC);
        vm.expectRevert(NonTransferable.selector);
        keep.safeTransferFrom(userC, userA, id, amount, "");
        vm.stopPrank();

        assert(keep.balanceOf(userA, id) == preBalanceA);
        assert(keep.balanceOf(userB, id) == preBalanceB);
        assert(keep.balanceOf(userC, id) == preBalanceC + amount);
    }

    function testCannotTransferExecuteOverflow() public payable {
        startHoax(address(keep), address(keep), type(uint256).max);
        keep.setTransferability(SIGNER_KEY, true);
        keep.mint(charlie, SIGNER_KEY, 1, "");
        vm.stopPrank();

        vm.prank(charlie);
        keep.safeTransferFrom(charlie, address(0xBeef), SIGNER_KEY, 1, "");
        vm.stopPrank();

        startHoax(address(keep), address(keep), type(uint256).max);
        keep.mint(charlie, SIGNER_KEY, 1, "");
        vm.stopPrank();

        vm.prank(charlie);
        vm.expectRevert(Overflow.selector);
        keep.safeTransferFrom(charlie, address(0xBeef), SIGNER_KEY, 1, "");
        vm.stopPrank();

        startHoax(address(keep), address(keep), type(uint256).max);
        keep.burn(address(0xBeef), SIGNER_KEY, 1);
        vm.stopPrank();
    }

    function testCannotTransferKeepTokenNonTransferable(uint256 id)
        public
        payable
    {
        vm.assume(id != SIGNER_KEY);

        vm.prank(address(keep));
        keep.mint(charlie, id, 1, "");
        vm.stopPrank();

        uint256 charlieBalance = keep.balanceOf(charlie, id);
        uint256 bobBalance = keep.balanceOf(bob, id);

        vm.startPrank(charlie);
        keep.setApprovalForAll(alice, true);
        vm.expectRevert(NonTransferable.selector);
        keep.safeTransferFrom(charlie, bob, id, 1, "");
        vm.stopPrank();

        assertTrue(keep.isApprovedForAll(charlie, alice));

        vm.prank(alice);
        vm.expectRevert(NonTransferable.selector);
        keep.safeTransferFrom(charlie, bob, id, 1, "");
        vm.stopPrank();

        assert(keep.balanceOf(charlie, id) == charlieBalance);
        assert(keep.balanceOf(bob, id) == bobBalance);
    }

    function testCannotTransferBatchKeepTokenNonTransferable() public payable {
        startHoax(address(keep), address(keep), type(uint256).max);
        keep.setTransferability(0, true);
        keep.setTransferability(1, false);
        vm.stopPrank();

        assertTrue(keep.transferable(0));
        assertFalse(keep.transferable(1));

        startHoax(address(keep), address(keep), type(uint256).max);
        keep.mint(charlie, 0, 1, "");
        keep.mint(charlie, 1, 2, "");
        vm.stopPrank();

        uint256[] memory ids = new uint256[](2);
        ids[0] = 0;
        ids[1] = 1;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1;
        amounts[1] = 1;

        startHoax(charlie, charlie, type(uint256).max);
        vm.expectRevert(NonTransferable.selector);
        keep.safeBatchTransferFrom(charlie, bob, ids, amounts, "");
        vm.stopPrank();

        assert(keep.balanceOf(charlie, 0) == 1);
        assert(keep.balanceOf(charlie, 1) == 2);
        assert(keep.balanceOf(bob, 0) == 0);
        assert(keep.balanceOf(bob, 1) == 0);
    }

    function testCannotTransferKeepTokenWithUnderflow(uint256 id)
        public
        payable
    {
        vm.assume(id != 1816876358);
        vm.assume(id != SIGNER_KEY);

        vm.prank(address(keep));
        keep.setTransferability(id, true);
        vm.stopPrank();

        assertTrue(keep.transferable(id));

        vm.prank(address(keep));
        keep.mint(charlie, id, 1, "");
        vm.stopPrank();

        vm.prank(charlie);
        vm.expectRevert(stdError.arithmeticError);
        keep.safeTransferFrom(charlie, bob, id, 2, "");
        vm.stopPrank();

        assert(keep.balanceOf(charlie, id) == 1);
        assert(keep.balanceOf(bob, id) == 0);
    }

    function testCannotTransferKeepTokenWithoutPermission(
        address userA,
        address userB,
        uint256 id,
        uint256 amount
    ) public payable {
        vm.assume(userA != address(0));
        vm.assume(userB != address(0));
        vm.assume(userA != userB);
        vm.assume(userA.code.length == 0);
        vm.assume(userB.code.length == 0);
        vm.assume(id != CORE_KEY);

        amount = bound(amount, 0, type(uint216).max);
        if (
            id == SIGNER_KEY &&
            (keep.balanceOf(userA, id) != 0 || keep.balanceOf(userB, id) != 0)
        ) {
            amount = amount - 1;
        }

        startHoax(address(keep), address(keep), type(uint256).max);
        keep.mint(userA, id, amount, "");
        keep.setTransferability(id, true);
        keep.setPermission(id, true);
        vm.stopPrank();

        assertTrue(keep.transferable(id));
        assertTrue(keep.permissioned(id));

        startHoax(userA, userA, type(uint256).max);
        vm.expectRevert(NotPermitted.selector);
        keep.safeTransferFrom(userA, userB, id, amount, "");
        vm.stopPrank();

        assert(keep.balanceOf(userA, id) == amount);
        assert(keep.balanceOf(userB, id) == 0);
    }

    function testCannotTransferKeepERC1155ToZeroAddress() public payable {
        // Mint and allow transferability.
        startHoax(address(keep), address(keep), type(uint256).max);
        keep.mint(alice, 2, 1, "");
        keep.setTransferability(2, true);
        vm.stopPrank();

        // Fail on zero address.
        startHoax(address(alice), address(alice), type(uint256).max);
        vm.expectRevert(InvalidRecipient.selector);
        keep.safeTransferFrom(alice, address(0), 2, 1, "");

        // Success on non-zero address.
        keep.safeTransferFrom(alice, bob, 2, 1, "");
        vm.stopPrank();
    }

    function testCannotBatchTransferKeepERC1155ToZeroAddress() public payable {
        // Mint and allow transferability.
        startHoax(address(keep), address(keep), type(uint256).max);
        keep.mint(alice, 2, 1, "");
        keep.setTransferability(2, true);
        vm.stopPrank();

        uint256[] memory ids = new uint256[](1);
        ids[0] = 2;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        // Fail on zero address.
        startHoax(address(alice), address(alice), type(uint256).max);
        vm.expectRevert(InvalidRecipient.selector);
        keep.safeBatchTransferFrom(alice, address(0), ids, amounts, "");

        // Success on non-zero address.
        keep.safeBatchTransferFrom(alice, bob, ids, amounts, "");
        vm.stopPrank();
    }

    function testCannotTransferKeepERC1155ToUnsafeContractAddress()
        public
        payable
    {
        // Mint and allow transferability.
        startHoax(address(keep), address(keep), type(uint256).max);
        keep.mint(alice, 2, 1, "");
        keep.setTransferability(2, true);
        vm.stopPrank();

        // Fail on receiver-noncompliant addresses.
        startHoax(address(alice), address(alice), type(uint256).max);
        vm.expectRevert();
        keep.safeTransferFrom(alice, address(mockDai), 2, 1, "");

        vm.expectRevert(UnsafeRecipient.selector);
        keep.safeTransferFrom(
            alice,
            address(mockUnsafeERC1155Receiver),
            2,
            1,
            ""
        );

        // Success on receiver-compliant address.
        keep.safeTransferFrom(alice, address(keep), 2, 1, "");
        vm.stopPrank();
    }

    function testCannotBatchTransferKeepERC1155ToUnsafeContractAddress()
        public
        payable
    {
        // Mint and allow transferability.
        startHoax(address(keep), address(keep), type(uint256).max);
        keep.mint(alice, 2, 1, "");
        keep.setTransferability(2, true);
        vm.stopPrank();

        uint256[] memory ids = new uint256[](1);
        ids[0] = 2;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        // Fail on receiver-noncompliant addresses.
        startHoax(address(alice), address(alice), type(uint256).max);
        vm.expectRevert();
        keep.safeBatchTransferFrom(alice, address(mockDai), ids, amounts, "");

        vm.expectRevert(UnsafeRecipient.selector);
        keep.safeBatchTransferFrom(
            alice,
            address(mockUnsafeERC1155Receiver),
            ids,
            amounts,
            ""
        );

        // Success on receiver-compliant address.
        keep.safeBatchTransferFrom(alice, address(keep), ids, amounts, "");
        vm.stopPrank();
    }

    /// -----------------------------------------------------------------------
    /// Keep Vote Delegation Tests
    /// -----------------------------------------------------------------------

    function testKeepTokenInitDelegationBalance(
        address user,
        uint256 id,
        uint256 amount
    ) public payable {
        vm.assume(user != address(0));
        vm.assume(user.code.length == 0);
        vm.assume(id != SIGNER_KEY);

        amount = bound(amount, 0, type(uint216).max);

        vm.warp(1665378008);

        vm.startPrank(address(keep));
        keep.mint(user, id, amount, "");
        vm.stopPrank();

        assert(keep.delegates(user, id) == user);
        assert(keep.getCurrentVotes(user, id) == amount);
        assert(keep.getVotes(user, id) == amount);

        vm.warp(1665378010);

        assert(keep.getPriorVotes(user, id, block.timestamp - 1) == amount);
        assert(keep.getPastVotes(user, id, block.timestamp - 1) == amount);
    }

    function testKeepTokenDelegation(
        address userA,
        address userB,
        uint256 id,
        uint256 amount
    ) public payable {
        amount = bound(amount, 0, type(uint216).max);
        vm.assume(userA != address(0));
        vm.assume(userB != address(0));
        vm.assume(userA != userB);
        vm.assume(userA.code.length == 0);
        vm.assume(userB.code.length == 0);
        vm.assume(id != SIGNER_KEY);

        vm.warp(1665378008);

        vm.startPrank(address(keep));
        keep.mint(userA, id, amount, "");
        vm.stopPrank();

        assert(keep.delegates(userA, id) == userA);
        assert(keep.getCurrentVotes(userA, id) == amount);
        assert(keep.getVotes(userA, id) == amount);

        assert(keep.getCurrentVotes(userB, id) == 0);
        assert(keep.getVotes(userB, id) == 0);

        vm.warp(1665378010);

        assert(keep.getPriorVotes(userA, id, block.timestamp - 1) == amount);
        assert(keep.getPastVotes(userA, id, block.timestamp - 1) == amount);

        assert(keep.getPriorVotes(userB, id, block.timestamp - 1) == 0);
        assert(keep.getPastVotes(userB, id, block.timestamp - 1) == 0);

        vm.startPrank(userA);
        keep.delegate(userB, id);
        vm.stopPrank();

        assert(keep.delegates(userA, id) == userB);

        assert(keep.getCurrentVotes(userA, id) == 0);
        assert(keep.getVotes(userA, id) == 0);

        assert(keep.getCurrentVotes(userB, id) == amount);
        assert(keep.getVotes(userB, id) == amount);

        assert(keep.getPriorVotes(userA, id, block.timestamp - 1) == amount);
        assert(keep.getPastVotes(userA, id, block.timestamp - 1) == amount);

        vm.warp(1665378015);

        assert(keep.getPriorVotes(userA, id, block.timestamp - 1) == 0);
        assert(keep.getPastVotes(userA, id, block.timestamp - 1) == 0);

        assert(keep.getPriorVotes(userB, id, block.timestamp - 1) == amount);
        assert(keep.getPastVotes(userB, id, block.timestamp - 1) == amount);
    }

    function testKeepTokenDelegationBalanceByTransfer(
        address userA,
        address userB,
        uint256 id,
        uint256 amount
    ) public payable {
        amount = bound(amount, 0, type(uint216).max);
        vm.assume(userA != address(0));
        vm.assume(userB != address(0));
        vm.assume(userA != userB);
        vm.assume(userA.code.length == 0);
        vm.assume(userB.code.length == 0);
        vm.assume(id != SIGNER_KEY);
        vm.assume(id != CORE_KEY);

        vm.warp(1665378008);

        startHoax(address(keep), address(keep), type(uint256).max);
        keep.mint(userA, id, amount, "");
        vm.stopPrank();

        assert(keep.delegates(userA, id) == userA);

        assert(keep.getCurrentVotes(userA, id) == amount);
        assert(keep.getVotes(userA, id) == amount);

        assert(keep.getCurrentVotes(userB, id) == 0);
        assert(keep.getVotes(userB, id) == 0);

        vm.warp(1665378010);

        assert(keep.getPriorVotes(userA, id, block.timestamp - 1) == amount);
        assert(keep.getPastVotes(userA, id, block.timestamp - 1) == amount);

        assert(keep.getPriorVotes(userB, id, block.timestamp - 1) == 0);
        assert(keep.getPastVotes(userB, id, block.timestamp - 1) == 0);

        startHoax(address(keep), address(keep), type(uint256).max);
        keep.setTransferability(id, true);
        vm.stopPrank();

        assertTrue(keep.transferable(id));

        startHoax(userA, userA, type(uint256).max);
        keep.safeTransferFrom(userA, userB, id, amount, "");
        vm.stopPrank();

        assert(keep.delegates(userA, id) == userA);

        assert(keep.getCurrentVotes(userA, id) == 0);
        assert(keep.getVotes(userA, id) == 0);

        assert(keep.getCurrentVotes(userB, id) == amount);
        assert(keep.getVotes(userB, id) == amount);

        assert(keep.getPriorVotes(userA, id, block.timestamp - 1) == amount);
        assert(keep.getPastVotes(userA, id, block.timestamp - 1) == amount);

        vm.warp(1665378015);

        assert(keep.getPriorVotes(userA, id, block.timestamp - 1) == 0);
        assert(keep.getPastVotes(userA, id, block.timestamp - 1) == 0);

        assert(keep.getPriorVotes(userB, id, block.timestamp - 1) == amount);
        assert(keep.getPastVotes(userB, id, block.timestamp - 1) == amount);
    }

    /// -----------------------------------------------------------------------
    /// Keep MetaTx Tests
    /// -----------------------------------------------------------------------

    function testKeepTokenPermit(address userB, bool approved) public payable {
        uint256 privateKey = 0xBEEF;
        address userA = vm.addr(0xBEEF);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    keep.DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            PERMIT_TYPEHASH,
                            userA,
                            userB,
                            approved,
                            0,
                            block.timestamp
                        )
                    )
                )
            )
        );

        vm.startPrank(userA);
        keep.permit(userA, userB, approved, block.timestamp, v, r, s);
        vm.stopPrank();

        assert(keep.isApprovedForAll(userA, userB) == approved);
        assert(keep.nonces(userA) == 1);
    }

    function testCannotSpendKeepTokenPermitAfterDeadline(
        address userB,
        bool approved
    ) public payable {
        uint256 privateKey = 0xBEEF;
        address userA = vm.addr(0xBEEF);

        uint256 deadline = block.timestamp;

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    keep.DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            PERMIT_TYPEHASH,
                            userA,
                            userB,
                            approved,
                            0,
                            deadline
                        )
                    )
                )
            )
        );

        // Shift into future.
        vm.warp(block.timestamp + 1);

        vm.startPrank(userA);
        vm.expectRevert(ExpiredSig.selector);
        keep.permit(userA, userB, approved, deadline, v, r, s);
        vm.stopPrank();
    }

    function testKeepTokenDelegateBySig(
        address userB,
        uint256 id,
        uint256 amount
    ) public payable {
        amount = bound(amount, 0, type(uint216).max);
        vm.assume(userB != address(0));
        vm.assume(userB.code.length == 0);
        vm.assume(id != SIGNER_KEY);

        uint256 privateKey = 0xBEEF;
        address userA = vm.addr(0xBEEF);

        vm.prank(address(keep));
        keep.mint(userA, id, amount, "");
        vm.stopPrank();

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    keep.DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            DELEGATION_TYPEHASH,
                            userA,
                            userB,
                            id,
                            0,
                            block.timestamp
                        )
                    )
                )
            )
        );

        vm.startPrank(userA);
        keep.delegateBySig(userA, userB, id, block.timestamp, v, r, s);
        vm.stopPrank();

        assert(keep.delegates(userA, id) == userB);
        assert(keep.nonces(userA) == 1);
    }

    function testCannotSpendKeepTokenDelegateBySigAfterDeadline(
        address userB,
        uint256 id
    ) public payable {
        uint256 privateKey = 0xBEEF;
        address userA = vm.addr(0xBEEF);

        uint256 deadline = block.timestamp;

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    keep.DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            DELEGATION_TYPEHASH,
                            userA,
                            userB,
                            id,
                            0,
                            block.timestamp
                        )
                    )
                )
            )
        );

        // Shift into future.
        vm.warp(block.timestamp + 1);

        vm.startPrank(userA);
        vm.expectRevert(ExpiredSig.selector);
        keep.delegateBySig(userA, userB, id, deadline, v, r, s);
        vm.stopPrank();
    }
}
