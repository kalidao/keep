// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {ERC1155TokenReceiver, Operation, Call, Signature, Keep} from "../src/Keep.sol";
import {KeepFactory} from "../src/KeepFactory.sol";

import {URIFetcher} from "../src/extensions/URIFetcher.sol";
import {URIRemoteFetcher} from "../src/extensions/URIRemoteFetcher.sol";

import {MockERC20} from "@solbase/test/utils/mocks/MockERC20.sol";
import {MockERC721} from "@solbase/test/utils/mocks/MockERC721.sol";
import {MockERC1155} from "@solbase/test/utils/mocks/MockERC1155.sol";

import {MockSmartWallet} from "./mocks/MockSmartWallet.sol";

import "@std/Test.sol";

contract KeepTest is Test, ERC1155TokenReceiver {
    using stdStorage for StdStorage;

    address keepAddr;
    address keepAddrRepeat;
    Keep keep;
    Keep keepRepeat;
    KeepFactory factory;
    URIFetcher uriFetcher;
    URIRemoteFetcher uriRemote;
    URIRemoteFetcher uriRemoteNew;
    MockERC20 mockDai;
    MockERC721 mockNFT;
    MockERC1155 mock1155;
    MockERC1271Wallet mockERC1271Wallet;

    uint256 internal EXECUTE_ID;

    /// @dev Users.

    uint256 immutable alicesPk =
        0x60b919c82f0b4791a5b7c6a7275970ace1748759ebdaa4076d7eeed9dbcff3c3;
    address public immutable alice = 0x503408564C50b43208529faEf9bdf9794c015d52;

    uint256 immutable bobsPk =
        0xf8f8a2f43c8376ccb0871305060d7b27b0554d2cc72bccf41b2705608452f315;
    address public immutable bob = 0x001d3F1ef827552Ae1114027BD3ECF1f086bA0F9;

    uint256 immutable charliesPk =
        0xb9dee2522aae4d21136ba441f976950520adf9479a3c0bda0a88ffc81495ded3;
    address public immutable charlie =
        0xccc4A5CeAe4D88Caf822B355C02F9769Fb6fd4fd;

    uint256 immutable nullPk =
        0x8b2ed20f3cc3dd482830910365cfa157e7568b9c3fa53d9edd3febd61086b9be;
    address public immutable nully = 0x0ACDf2aC839B7ff4cd5F16e884B2153E902253f2;

    /// @dev Helpers.

    Call[] calls;

    uint256 chainId;

    bytes32 name =
        0x5445535400000000000000000000000000000000000000000000000000000000;

    bytes32 name2 =
        0x5445535432000000000000000000000000000000000000000000000000000000;

    function getDigest(
        Operation op,
        address to,
        uint256 value,
        bytes memory data,
        uint256 nonce,
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
                                "Execute(Operation op,address to,uint256 value,bytes data,uint256 nonce)"
                            ),
                            op,
                            to,
                            value,
                            data,
                            nonce
                        )
                    )
                )
            );
    }

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

    function writeTokenBalance(
        address who,
        address token,
        uint256 amt
    ) internal {
        stdstore
            .target(token)
            .sig(MockERC20(token).balanceOf.selector)
            .with_key(who)
            .checked_write(amt);
    }

    function signExecution(
        address user,
        uint256 pk,
        Operation op,
        address to,
        uint256 value,
        bytes memory data
    ) internal returns (Signature memory sig) {
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            pk,
            getDigest(
                op,
                address(to),
                value,
                data,
                keep.nonce(),
                computeDomainSeparator(address(keep))
            )
        );
        // set 'wrong v' to return null signer for tests
        if (pk == nullPk) v = 17;

        sig = Signature({user: user, v: v, r: r, s: s});
    }

    /// -----------------------------------------------------------------------
    /// Keep Setup Tests
    /// -----------------------------------------------------------------------

    /// @notice Set up the testing suite.

    function setUp() public payable {
        // Initialize templates.
        uriRemote = new URIRemoteFetcher(alice);
        uriRemoteNew = new URIRemoteFetcher(bob);
        uriFetcher = new URIFetcher(alice, uriRemote);
        keep = new Keep(Keep(address(uriFetcher)));
        mockDai = new MockERC20("Dai", "DAI", 18);
        mockNFT = new MockERC721("NFT", "NFT");
        mock1155 = new MockERC1155();
        mockERC1271Wallet = new MockERC1271Wallet(alice);

        // Mint mock ERC20.
        mockDai.mint(address(this), 1000000000 * 1e18);
        // Mint mock 721.
        mockNFT.mint(address(this), 1);
        // Mint mock 1155.
        mock1155.mint(address(this), 1, 1, "");

        // Create the factory.
        factory = new KeepFactory(keep);

        // Create the Signer[].
        address[] memory signers = new address[](2);
        signers[0] = alice > bob ? bob : alice;
        signers[1] = alice > bob ? alice : bob;

        // Initialize Keep from factory.
        // The factory is fully tested in KeepFactory.t.sol.
        keepAddr = factory.determineKeep(name);
        keep = Keep(keepAddr);

        factory.deployKeep(name, calls, signers, 2);
        EXECUTE_ID = uint32(keep.execute.selector);

        // Approve Keep as spender of mock ERC20.
        mockDai.approve(address(keep), type(uint256).max);

        // Mint mock smart wallet a signer ID.
        vm.prank(address(keep));
        keep.mint(address(mockERC1271Wallet), EXECUTE_ID, 1, "");
        vm.stopPrank();

        // Store chainId.
        chainId = block.chainid;
    }

    /// @notice Check setup conditions.

    function testURISetup() public payable {
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
        uriFetcher.setURIRemoteFetcher(uriRemoteNew);
        vm.stopPrank();

        vm.prank(address(alice));
        vm.expectRevert(bytes4(keccak256("Unauthorized()")));
        uriRemoteNew.setURI(address(keep), 0, "");
        vm.stopPrank();

        vm.prank(address(bob));
        uriRemoteNew.setURI(address(keep), 0, "NEW");
        vm.stopPrank();

        assertEq(keep.uri(0), "NEW");
        assertEq(keep.uri(1), "");
    }

    function testSignerSetup() public payable {
        // Check users.
        assertTrue(keep.balanceOf(alice, EXECUTE_ID) == 1);
        assertTrue(keep.balanceOf(bob, EXECUTE_ID) == 1);
        assertTrue(keep.balanceOf(charlie, EXECUTE_ID) == 0);

        // Also check smart wallet.
        assertTrue(keep.balanceOf(address(mockERC1271Wallet), EXECUTE_ID) == 1);

        // Check supply.
        assertTrue(keep.totalSupply(EXECUTE_ID) == 3);
        assertTrue(keep.totalSupply(42069) == 0);
    }

    /// @notice Check setup errors.

    function testCannotRepeatKeepSetup() public payable {
        keepRepeat = new Keep(Keep(address(uriFetcher)));

        // Create the Signer[].
        address[] memory signers = new address[](2);
        signers[0] = alice > bob ? bob : alice;
        signers[1] = alice > bob ? alice : bob;

        keepAddrRepeat = factory.determineKeep(name2);
        keepRepeat = Keep(keepAddrRepeat);
        factory.deployKeep(name2, calls, signers, 2);

        vm.expectRevert(bytes4(keccak256("AlreadyInit()")));
        keepRepeat.initialize(calls, signers, 2);
    }

    function testCannotZeroQuorumSetup() public payable {
        // Create the Signer[].
        address[] memory signers = new address[](2);
        signers[0] = alice > bob ? bob : alice;
        signers[1] = alice > bob ? alice : bob;

        vm.expectRevert(bytes(""));
        factory.deployKeep(name2, calls, signers, 0);
    }

    function testCannotExcessiveQuorumSetup() public payable {
        // Create the Signer[].
        address[] memory signers = new address[](2);
        signers[0] = alice > bob ? bob : alice;
        signers[1] = alice > bob ? alice : bob;

        vm.expectRevert(bytes4(keccak256("QuorumOverSupply()")));
        factory.deployKeep(name2, calls, signers, 3);
    }

    function testCannotOutOfOrderSignerSetup() public payable {
        // Create the Signer[].
        address[] memory signers = new address[](2);
        signers[0] = alice > bob ? alice : bob;
        signers[1] = alice > bob ? bob : alice;

        vm.expectRevert(bytes4(keccak256("InvalidSig()")));
        factory.deployKeep(name2, calls, signers, 2);
    }

    /// -----------------------------------------------------------------------
    /// Keep State Tests
    /// -----------------------------------------------------------------------

    function testNonce() public view {
        assert(keep.nonce() == 0);
    }

    function testName() public {
        assertEq(keep.name(), string(abi.encodePacked(name)));
    }

    // We use this to check fetching when exposing function as `public`.
    /*function testInitChainId() public {
        assertEq(keep._initialChainId(), block.chainid);
    }*/

    function testQuorum() public payable {
        assert(keep.quorum() == 2);
        assert(keep.totalSupply(EXECUTE_ID) == 3);

        vm.prank(address(keep));
        keep.mint(charlie, EXECUTE_ID, 1, "");
        vm.stopPrank();

        assert(keep.totalSupply(EXECUTE_ID) == 4);

        vm.prank(address(keep));
        keep.setQuorum(3);
        vm.stopPrank();

        assert(keep.quorum() == 3);
    }

    function testTotalSignerSupply() public view {
        assert(keep.totalSupply(EXECUTE_ID) == 3);
    }

    /// -----------------------------------------------------------------------
    /// Operations Tests
    /// -----------------------------------------------------------------------

    function testReceiveETH() public payable {
        (bool sent, ) = address(keep).call{value: 5 ether}("");
        assert(sent);
    }

    function testReceiveERC721() public payable {
        mockNFT.safeTransferFrom(address(this), address(keep), 1);
        assertTrue(mockNFT.ownerOf(1) == address(keep));
    }

    function testReceiveStandardERC1155() public payable {
        mock1155.safeTransferFrom(address(this), address(keep), 1, 1, "");
        assertTrue(mock1155.balanceOf(address(keep), 1) == 1);
    }

    function testReceiveKeepERC1155() public payable {
        address local = address(this);
        vm.prank(address(keep));
        keep.mint(local, 2, 1, "");
        vm.stopPrank();

        vm.prank(address(keep));
        keep.setTransferability(2, true);
        vm.stopPrank();

        keep.safeTransferFrom(local, address(keep), 2, 1, "");
    }

    function testCannotTransferKeepERC1155ToZeroAddress() public payable {
        // Allow transferability
        startHoax(address(keep), address(keep), type(uint256).max);
        keep.mint(alice, 2, 1, "");
        keep.setTransferability(2, true);
        vm.stopPrank();
        // Fail on zero address
        startHoax(alice, alice, type(uint256).max);
        vm.expectRevert(bytes4(keccak256("InvalidRecipient()")));
        keep.safeTransferFrom(alice, address(0), 2, 1, "");
        // Success on non-zero address
        keep.safeTransferFrom(alice, bob, 2, 1, "");
        vm.stopPrank();
    }

    /// @notice Check execution.

    function testExecuteCallWithRole() public payable {
        uint256 nonceInit = keep.nonce();
        address aliceAddress = address(alice);

        mockDai.transfer(address(keep), 100);

        startHoax(address(keep), address(keep), type(uint256).max);
        keep.mint(alice, uint32(keep.multiExecute.selector), 1, "");
        vm.stopPrank();

        startHoax(address(alice), address(alice), type(uint256).max);

        bytes memory data = "";

        assembly {
            mstore(add(data, 0x20), shl(0xE0, 0xa9059cbb)) // `transfer(address,uint256)`.
            mstore(add(data, 0x24), aliceAddress)
            mstore(add(data, 0x44), 100)
            mstore(data, 0x44)
            // Update free memory pointer.
            mstore(0x40, add(data, 0x100))
        }

        Call[] memory call = new Call[](1);

        call[0].op = Operation.call;
        call[0].to = address(mockDai);
        call[0].value = 0;
        call[0].data = data;

        keep.multiExecute(call);
        vm.stopPrank();
        assert(mockDai.balanceOf(alice) == 100);
        uint256 nonceAfter = keep.nonce();
        assert((nonceInit + 1) == nonceAfter);
    }

    function testExecuteCallWithSignatures() public payable {
        mockDai.transfer(address(keep), 100);
        address aliceAddress = alice;
        bytes memory tx_data = "";

        assembly {
            mstore(add(tx_data, 0x20), shl(0xE0, 0xa9059cbb)) // `transfer(address,uint256)`.
            mstore(add(tx_data, 0x24), aliceAddress)
            mstore(add(tx_data, 0x44), 100)
            mstore(tx_data, 0x44)
            // Update free memory pointer.
            mstore(0x40, add(tx_data, 0x80))
        }

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

        sigs[0] = alice > bob ? bobSig : aliceSig;
        sigs[1] = alice > bob ? aliceSig : bobSig;

        // Execute tx.
        keep.execute(Operation.call, address(mockDai), 0, tx_data, sigs);
    }

    function testExecuteDelegateCallWithSignatures() public payable {
        mockDai.transfer(address(keep), 100);
        address aliceAddress = alice;
        bytes memory tx_data = "";

        assembly {
            mstore(add(tx_data, 0x20), shl(0xE0, 0x70a08231)) // `balanceOf(address)`.
            mstore(add(tx_data, 0x24), aliceAddress)
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

        sigs[0] = alice > bob ? bobSig : aliceSig;
        sigs[1] = alice > bob ? aliceSig : bobSig;

        // Execute tx.
        keep.execute(
            Operation.delegatecall,
            address(mockDai),
            0,
            tx_data,
            sigs
        );
    }

    /// @notice Check execution malconditions.

    function testCannotExecuteWithImproperSignatures() public payable {
        mockDai.transfer(address(keep), 100);
        address aliceAddress = alice;
        bytes memory tx_data = "";

        assembly {
            mstore(add(tx_data, 0x20), shl(0xE0, 0xa9059cbb)) // `transfer(address,uint256)`.
            mstore(add(tx_data, 0x24), aliceAddress)
            mstore(add(tx_data, 0x44), 100)
            mstore(tx_data, 0x44)
            // Update free memory pointer.
            mstore(0x40, add(tx_data, 0x80))
        }

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

        vm.expectRevert();
        // Execute tx.
        keep.execute(Operation.call, address(mockDai), 0, tx_data, sigs);
    }

    function testCannotExecuteWithSignaturesOutOfOrder() public payable {
        mockDai.transfer(address(keep), 100);
        address aliceAddress = alice;
        bytes memory tx_data = "";

        assembly {
            mstore(add(tx_data, 0x20), shl(0xE0, 0xa9059cbb)) // `transfer(address,uint256)`.
            mstore(add(tx_data, 0x24), aliceAddress)
            mstore(add(tx_data, 0x44), 100)
            mstore(tx_data, 0x44)
            // Update free memory pointer.
            mstore(0x40, add(tx_data, 0x80))
        }

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

        vm.expectRevert(bytes4(keccak256("InvalidSig()")));
        // Execute tx.
        keep.execute(Operation.call, address(mockDai), 0, tx_data, sigs);
    }

    function testCannotExecuteWithSignaturesRepeated() public payable {
        mockDai.transfer(address(keep), 100);
        address aliceAddress = alice;
        bytes memory tx_data = "";

        assembly {
            mstore(add(tx_data, 0x20), shl(0xE0, 0xa9059cbb)) // `transfer(address,uint256)`.
            mstore(add(tx_data, 0x24), aliceAddress)
            mstore(add(tx_data, 0x44), 100)
            mstore(tx_data, 0x44)
            // Update free memory pointer.
            mstore(0x40, add(tx_data, 0x80))
        }

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

        vm.expectRevert(bytes4(keccak256("InvalidSig()")));
        // Execute tx.
        keep.execute(Operation.call, address(mockDai), 0, tx_data, sigs);
    }

    function testCannotExecuteWithNullSignatures() public payable {
        mockDai.transfer(address(keep), 100);
        address aliceAddress = alice;
        bytes memory tx_data = "";

        assembly {
            mstore(add(tx_data, 0x20), shl(0xE0, 0xa9059cbb)) // `transfer(address,uint256)`.
            mstore(add(tx_data, 0x24), aliceAddress)
            mstore(add(tx_data, 0x44), 100)
            mstore(tx_data, 0x44)
            // Update free memory pointer.
            mstore(0x40, add(tx_data, 0x80))
        }

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

        vm.expectRevert();
        // Execute tx.
        keep.execute(Operation.call, address(mockDai), 0, tx_data, sigs);
    }

    function testExecuteCallWithContractSignatures() public payable {
        mockDai.transfer(address(keep), 100);
        address aliceAddress = alice;
        bytes memory tx_data = "";

        assembly {
            mstore(add(tx_data, 0x20), shl(0xE0, 0xa9059cbb)) // `transfer(address,uint256)`.
            mstore(add(tx_data, 0x24), aliceAddress)
            mstore(add(tx_data, 0x44), 100)
            mstore(tx_data, 0x44)
            // Update free memory pointer.
            mstore(0x40, add(tx_data, 0x80))
        }

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

        sigs[0] = alice > bob ? bobSig : aliceSig;
        sigs[1] = alice > bob ? aliceSig : bobSig;

        // Execute tx.
        keep.execute(Operation.call, address(mockDai), 0, tx_data, sigs);
    }

    /// @notice Check governance.
    function testMint(
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) public payable {
        vm.assume(id != EXECUTE_ID);
        vm.assume(keep.totalSupply(uint32(uint160(address(keep)))) == 0); // CORE_ID
        amount = bound(amount, 0, type(uint216).max);

        uint256 preTotalSupply = keep.totalSupply(id);
        uint256 preBalance = keep.balanceOf(charlie, id);

        vm.prank(address(keep));
        keep.mint(charlie, id, amount, data);

        assert(keep.balanceOf(charlie, id) == preBalance + amount);
        assert(keep.totalSupply(id) == preTotalSupply + amount);
    }

    function testMintExecuteId() public payable {
        uint256 executeTotalSupply = keep.totalSupply(EXECUTE_ID);
        uint256 executeBalance = keep.balanceOf(charlie, EXECUTE_ID);
        uint256 preQuorum = keep.quorum();

        vm.prank(address(keep));
        keep.mint(charlie, EXECUTE_ID, 1, "");

        assert(keep.balanceOf(charlie, EXECUTE_ID) == executeBalance + 1);
        assert(keep.totalSupply(EXECUTE_ID) == executeTotalSupply + 1);
        assert(keep.quorum() == preQuorum);
    }

    function testMintCoreId(uint256 amount) public payable {
        amount = bound(amount, 0, type(uint216).max);

        uint256 CORE_ID = uint32(uint160(address(keep)));
        uint256 totalSupply = keep.totalSupply(CORE_ID);
        uint256 balance = keep.balanceOf(charlie, CORE_ID);
        uint256 preQuorum = keep.quorum();

        vm.prank(address(keep));
        keep.mint(charlie, CORE_ID, amount, "");

        assert(keep.balanceOf(charlie, CORE_ID) == balance + amount);
        assert(keep.totalSupply(CORE_ID) == totalSupply + amount);
        assert(keep.quorum() == preQuorum);
        assert(keep.totalSupply(CORE_ID) == totalSupply + amount);
    }

    function testCannotMintZeroAddress() public payable {
        assert(keep.totalSupply(EXECUTE_ID) == 3);

        startHoax(address(keep), address(keep), type(uint256).max);
        vm.expectRevert(bytes4(keccak256("InvalidRecipient()")));
        keep.mint(address(0), EXECUTE_ID, 1, "");
        vm.stopPrank();

        startHoax(address(keep), address(keep), type(uint256).max);
        vm.expectRevert(bytes4(keccak256("InvalidRecipient()")));
        keep.mint(address(0), 1, 1, "");
        vm.stopPrank();

        assert(keep.balanceOf(address(0), EXECUTE_ID) == 0);
        assert(keep.balanceOf(address(0), 1) == 0);

        assert(keep.totalSupply(EXECUTE_ID) == 3);
        assert(keep.quorum() == 2);
    }

    function testCannotMintOverflowSupply() public payable {
        vm.prank(address(keep));
        keep.mint(charlie, 0, type(uint96).max, "");
        vm.stopPrank();

        vm.prank(address(keep));
        vm.expectRevert(bytes4(keccak256("Overflow()")));
        keep.mint(charlie, 1, type(uint256).max, "");
        vm.stopPrank();

        vm.prank(address(keep));
        keep.mint(charlie, 2, type(uint216).max, "");
        vm.stopPrank();

        vm.prank(address(keep));
        vm.expectRevert(bytes4(keccak256("Overflow()")));
        keep.mint(charlie, 2, 1, "");
        vm.stopPrank();

        uint256 amount = 1 << 216;

        vm.prank(address(keep));
        vm.expectRevert(bytes4(keccak256("Overflow()")));
        keep.mint(charlie, 3, amount, "");
        vm.stopPrank();
    }

    function testBurn() public {
        startHoax(address(keep), address(keep), type(uint256).max);
        keep.setQuorum(1);
        vm.stopPrank();

        assertTrue(keep.balanceOf(alice, EXECUTE_ID) == 1);

        vm.prank(address(keep));
        keep.burn(alice, EXECUTE_ID, 1);
        vm.stopPrank();

        assert(keep.totalSupply(EXECUTE_ID) == 2);
        assert(keep.quorum() == 1);
    }

    function testCannotBurnUnderflow() public payable {
        startHoax(address(keep), address(keep), type(uint256).max);
        keep.mint(alice, 1, 1, "");
        vm.expectRevert(stdError.arithmeticError);
        keep.burn(alice, 1, 2);
        vm.stopPrank();
    }

    function testRole() public payable {
        startHoax(charlie, charlie, type(uint256).max);
        vm.expectRevert(bytes4(keccak256("Unauthorized()")));
        keep.mint(alice, 1, 100, "");
        vm.stopPrank();

        startHoax(address(keep), address(keep), type(uint256).max);
        keep.mint(charlie, uint32(keep.mint.selector), 1, "");
        vm.stopPrank();

        startHoax(charlie, charlie, type(uint256).max);
        keep.mint(alice, 1, 100, "");
        vm.stopPrank();
        assert(keep.balanceOf(alice, 1) == 100);
    }

    function testSetTransferability() public payable {
        // The keep itself should be able to flip pause.
        //vm.assume(id != 742900294); // TODO: why

        startHoax(address(keep), address(keep), type(uint256).max);
        keep.setTransferability(1, true);
        assertTrue(keep.transferable(1) == true);
        keep.mint(charlie, 1, 1, "");
        vm.stopPrank();

        startHoax(charlie, charlie, type(uint256).max);
        keep.safeTransferFrom(charlie, alice, 1, 1, "");
        vm.stopPrank();

        startHoax(address(keep), address(keep), type(uint256).max);
        keep.setTransferability(1, false);
        assertTrue(!keep.transferable(1));
        vm.stopPrank();

        startHoax(alice, alice, type(uint256).max);
        vm.expectRevert(bytes4(keccak256("NonTransferable()")));
        keep.safeTransferFrom(alice, charlie, 1, 1, "");
        vm.stopPrank();
    }

    function testCannotSetTransferability(address dave, uint256 id)
        public
        payable
    {
        vm.assume(dave != address(keep));
        vm.prank(dave);
        vm.expectRevert(bytes4(keccak256("Unauthorized()")));
        keep.setTransferability(id, true);
        assertTrue(!keep.transferable(id));
    }

    function testSetURI(address dave) public payable {
        vm.prank(dave);
        vm.assume(dave != address(keep));
        vm.expectRevert(bytes4(keccak256("Unauthorized()")));
        keep.setURI(0, "new_base_uri");

        // The keep itself should be able to update uri.
        vm.prank(address(keep));
        keep.setURI(0, "new_base_uri");
        assertEq(
            keccak256(bytes("new_base_uri")),
            keccak256(bytes(keep.uri(0)))
        );
    }

    /// @notice Check token functionality.

    function testKeepTokenApprove() public payable {
        startHoax(alice, alice, type(uint256).max);
        keep.setApprovalForAll(bob, true);
        vm.stopPrank();
        assertTrue(keep.isApprovedForAll(alice, bob));

        startHoax(alice, alice, type(uint256).max);
        keep.setApprovalForAll(bob, false);
        vm.stopPrank();
        assertTrue(!keep.isApprovedForAll(alice, bob));
    }

    function testKeepTokenTransferByOwner(uint256 id, uint256 amount)
        public
        payable
    {
        amount = bound(amount, 0, type(uint216).max);

        vm.startPrank(address(keep));
        keep.setTransferability(id, true);
        assertTrue(keep.transferable(id) == true);
        keep.mint(charlie, id, amount, "");
        vm.stopPrank();

        uint256 charliePreBalance = keep.balanceOf(charlie, id);
        uint256 bobPreBalance = keep.balanceOf(bob, id);
        vm.prank(charlie);
        keep.safeTransferFrom(charlie, bob, id, amount, "");

        assertEq(keep.balanceOf(charlie, id), charliePreBalance - amount);
        assertEq(keep.balanceOf(bob, id), bobPreBalance + amount);
    }

    function testKeepTokenBatchTransferByOwner() public payable {
        startHoax(address(keep), address(keep), type(uint256).max);
        keep.setTransferability(0, true);
        keep.setTransferability(1, true);
        vm.stopPrank();
        assertTrue(keep.transferable(0) == true);
        assertTrue(keep.transferable(1) == true);

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

        assertTrue(keep.balanceOf(charlie, 0) == 0);
        assertTrue(keep.balanceOf(charlie, 1) == 1);
        assertTrue(keep.balanceOf(bob, 0) == 1);
        assertTrue(keep.balanceOf(bob, 1) == 1);
    }

    function testKeepTokenTransferByOperator(uint256 id) public payable {
        uint256 bobPreBalance = keep.balanceOf(bob, id);
        console.log(bobPreBalance);
        vm.startPrank(address(keep));
        keep.setTransferability(id, true);
        assertTrue(keep.transferable(id) == true);
        keep.mint(charlie, id, 1, "");
        vm.stopPrank();

        vm.prank(charlie);
        keep.setApprovalForAll(alice, true);
        assertTrue(keep.isApprovedForAll(charlie, alice));

        vm.prank(alice);
        keep.safeTransferFrom(charlie, bob, id, 1, "");

        assertTrue(keep.balanceOf(charlie, id) == 0);
        assertEq(keep.balanceOf(bob, id), bobPreBalance + 1);
    }

    function testKeepTokenBatchTransferByOperator() public payable {
        startHoax(address(keep), address(keep), type(uint256).max);
        keep.setTransferability(0, true);
        keep.setTransferability(1, true);
        vm.stopPrank();
        assertTrue(keep.transferable(0) == true);
        assertTrue(keep.transferable(1) == true);

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

        assertTrue(keep.balanceOf(charlie, 0) == 0);
        assertTrue(keep.balanceOf(charlie, 1) == 1);
        assertTrue(keep.balanceOf(bob, 0) == 1);
        assertTrue(keep.balanceOf(bob, 1) == 1);
    }

    function testKeepTokenTransferPermission(
        address userA,
        address userB,
        address userC,
        uint256 id,
        uint256 amount
    ) public payable {
        amount = bound(amount, 0, type(uint216).max);
        vm.assume(id != 2094031643); // Bad
        vm.assume(userA != address(0));
        vm.assume(userB != address(0));
        vm.assume(userC != address(0));
        vm.assume(userA != userB);
        vm.assume(userB != userC);
        vm.assume(userA != userC);
        vm.assume(userA.code.length == 0);
        vm.assume(userB.code.length == 0);
        vm.assume(userC.code.length == 0);

        uint256 preBalanceA = keep.balanceOf(userA, id);
        uint256 preBalanceB = keep.balanceOf(userB, id);
        uint256 preBalanceC = keep.balanceOf(userC, id);

        vm.startPrank(address(keep));

        keep.setTransferability(id, true);
        assertTrue(keep.transferable(id));

        keep.setPermission(id, true);
        assertTrue(keep.permissioned(id));

        keep.setUserPermission(userA, id, true);
        keep.setUserPermission(userB, id, true);
        assertTrue(keep.userPermissioned(userA, id));
        assertTrue(keep.userPermissioned(userB, id));
        assertFalse(keep.userPermissioned(userC, id));

        keep.mint(userA, id, amount, "");
        assertTrue(keep.balanceOf(userA, id) == preBalanceA + amount);
        vm.stopPrank();

        vm.prank(userA);
        keep.safeTransferFrom(userA, userB, id, amount, "");
        assertTrue(keep.balanceOf(userA, id) == preBalanceA);
        assertTrue(keep.balanceOf(userB, id) == preBalanceB + amount);

        vm.prank(userB);
        keep.setApprovalForAll(userC, true);
        assertTrue(keep.isApprovedForAll(userB, userC));

        vm.prank(userC);
        vm.expectRevert(bytes4(keccak256("NotPermitted()")));
        keep.safeTransferFrom(userB, userC, id, amount, ""); // C not permissioned

        assertTrue(keep.balanceOf(userA, id) == preBalanceA);
        assertTrue(keep.balanceOf(userB, id) == preBalanceB + amount);
        assertTrue(keep.balanceOf(userC, id) == preBalanceC);

        vm.prank(address(keep));
        keep.setUserPermission(userC, id, true);
        assertTrue(keep.userPermissioned(userC, id));

        vm.prank(userC);
        keep.safeTransferFrom(userB, userC, id, amount, "");

        assertTrue(keep.balanceOf(userB, id) == preBalanceB);
        assertTrue(keep.balanceOf(userC, id) == preBalanceC + amount);

        vm.prank(address(keep));
        keep.setTransferability(id, false);
        assertFalse(keep.transferable(id));

        vm.prank(userC);
        vm.expectRevert(bytes4(keccak256("NonTransferable()")));
        keep.safeTransferFrom(userC, userA, id, amount, "");

        assertTrue(keep.balanceOf(userA, id) == preBalanceA);
        assertTrue(keep.balanceOf(userB, id) == preBalanceB);
        assertTrue(keep.balanceOf(userC, id) == preBalanceC + amount);
    }

    function testCannotTransferKeepTokenNonTransferable(uint256 id)
        public
        payable
    {
        vm.prank(address(keep));
        keep.mint(charlie, id, 1, "");

        uint256 charlieBalance = keep.balanceOf(charlie, id);
        uint256 bobBalance = keep.balanceOf(bob, id);

        vm.startPrank(charlie);
        keep.setApprovalForAll(alice, true);
        assertTrue(keep.isApprovedForAll(charlie, alice));

        vm.expectRevert(bytes4(keccak256("NonTransferable()")));
        keep.safeTransferFrom(charlie, bob, id, 1, "");
        vm.stopPrank();

        vm.prank(alice);
        vm.expectRevert(bytes4(keccak256("NonTransferable()")));
        keep.safeTransferFrom(charlie, bob, id, 1, "");

        assertEq(keep.balanceOf(charlie, id), charlieBalance);
        assertEq(keep.balanceOf(bob, id), bobBalance);
    }

    function testCannotTransferKeepTokenNonTransferable() public payable {
        startHoax(address(keep), address(keep), type(uint256).max);
        keep.setTransferability(0, true);
        keep.setTransferability(1, false);
        vm.stopPrank();
        assertTrue(keep.transferable(0) == true);
        assertTrue(keep.transferable(1) == false);

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
        vm.expectRevert(bytes4(keccak256("NonTransferable()")));
        keep.safeBatchTransferFrom(charlie, bob, ids, amounts, "");
        vm.stopPrank();

        assertTrue(keep.balanceOf(charlie, 0) == 1);
        assertTrue(keep.balanceOf(charlie, 1) == 2);
        assertTrue(keep.balanceOf(bob, 0) == 0);
        assertTrue(keep.balanceOf(bob, 1) == 0);
    }

    function testCannotTransferKeepTokenWithUnderflow(uint256 id)
        public
        payable
    {
        vm.assume(id != 1816876358);

        startHoax(address(keep), address(keep), type(uint256).max);
        keep.setTransferability(id, true);
        vm.stopPrank();
        assertTrue(keep.transferable(id) == true);

        startHoax(address(keep), address(keep), type(uint256).max);
        keep.mint(charlie, id, 1, "");
        vm.stopPrank();

        startHoax(charlie, charlie, type(uint256).max);
        vm.expectRevert(stdError.arithmeticError);
        keep.safeTransferFrom(charlie, bob, id, 2, "");
        vm.stopPrank();

        assertTrue(keep.balanceOf(charlie, id) == 1);
        assertTrue(keep.balanceOf(bob, id) == 0);
    }

    function testCannotTransferKeepTokenWithoutPermission(
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

        startHoax(address(keep), address(keep), type(uint256).max);
        keep.setTransferability(id, true);
        vm.stopPrank();
        assertTrue(keep.transferable(id) == true);

        startHoax(address(keep), address(keep), type(uint256).max);
        keep.mint(userA, id, amount, "");
        keep.setPermission(id, true);
        vm.stopPrank();

        startHoax(userA, userA, type(uint256).max);
        vm.expectRevert(bytes4(keccak256("NotPermitted()")));
        keep.safeTransferFrom(userA, userB, id, amount, "");
        vm.stopPrank();

        assertTrue(keep.balanceOf(userA, id) == amount);
        assertTrue(keep.balanceOf(userB, id) == 0);
    }

    /// @dev Test delegation.

    function testKeepTokenInitDelegationBalance(
        address user,
        uint256 id,
        uint256 amount
    ) public payable {
        amount = bound(amount, 0, type(uint216).max);
        vm.assume(user != address(0));
        vm.assume(user.code.length == 0);
        vm.assume(id != EXECUTE_ID);

        vm.warp(1665378008);

        vm.startPrank(address(keep));
        keep.mint(user, id, amount, "");
        vm.stopPrank();

        assertTrue(keep.delegates(user, id) == user);

        assertTrue(keep.getCurrentVotes(user, id) == amount);
        assertTrue(keep.getVotes(user, id) == amount);

        vm.warp(1665378010);

        assertTrue(keep.getPriorVotes(user, id, block.timestamp - 1) == amount);
        assertTrue(keep.getPastVotes(user, id, block.timestamp - 1) == amount);
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
        vm.assume(id != EXECUTE_ID);

        vm.warp(1665378008);

        vm.startPrank(address(keep));
        keep.mint(userA, id, amount, "");
        vm.stopPrank();

        assertTrue(keep.delegates(userA, id) == userA);

        assertTrue(keep.getCurrentVotes(userA, id) == amount);
        assertTrue(keep.getVotes(userA, id) == amount);

        assertTrue(keep.getCurrentVotes(userB, id) == 0);
        assertTrue(keep.getVotes(userB, id) == 0);

        vm.warp(1665378010);

        assertTrue(
            keep.getPriorVotes(userA, id, block.timestamp - 1) == amount
        );
        assertTrue(keep.getPastVotes(userA, id, block.timestamp - 1) == amount);

        assertTrue(keep.getPriorVotes(userB, id, block.timestamp - 1) == 0);
        assertTrue(keep.getPastVotes(userB, id, block.timestamp - 1) == 0);

        vm.startPrank(userA);
        keep.delegate(userB, id);
        vm.stopPrank();

        assertTrue(keep.delegates(userA, id) == userB);

        assertTrue(keep.getCurrentVotes(userA, id) == 0);
        assertTrue(keep.getVotes(userA, id) == 0);

        assertTrue(keep.getCurrentVotes(userB, id) == amount);
        assertTrue(keep.getVotes(userB, id) == amount);

        assertTrue(
            keep.getPriorVotes(userA, id, block.timestamp - 1) == amount
        );
        assertTrue(keep.getPastVotes(userA, id, block.timestamp - 1) == amount);

        vm.warp(1665378015);

        assertTrue(keep.getPriorVotes(userA, id, block.timestamp - 1) == 0);
        assertTrue(keep.getPastVotes(userA, id, block.timestamp - 1) == 0);

        assertTrue(
            keep.getPriorVotes(userB, id, block.timestamp - 1) == amount
        );
        assertTrue(keep.getPastVotes(userB, id, block.timestamp - 1) == amount);
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
        vm.assume(id != EXECUTE_ID);

        vm.warp(1665378008);

        vm.startPrank(address(keep));
        keep.mint(userA, id, amount, "");
        vm.stopPrank();

        assertTrue(keep.delegates(userA, id) == userA);

        assertTrue(keep.getCurrentVotes(userA, id) == amount);
        assertTrue(keep.getVotes(userA, id) == amount);

        assertTrue(keep.getCurrentVotes(userB, id) == 0);
        assertTrue(keep.getVotes(userB, id) == 0);

        vm.warp(1665378010);

        assertTrue(
            keep.getPriorVotes(userA, id, block.timestamp - 1) == amount
        );
        assertTrue(keep.getPastVotes(userA, id, block.timestamp - 1) == amount);

        assertTrue(keep.getPriorVotes(userB, id, block.timestamp - 1) == 0);
        assertTrue(keep.getPastVotes(userB, id, block.timestamp - 1) == 0);

        vm.startPrank(address(keep));
        keep.setTransferability(id, true);
        assertTrue(keep.transferable(id));
        vm.stopPrank();

        vm.startPrank(userA);
        keep.safeTransferFrom(userA, userB, id, amount, "");
        vm.stopPrank();

        assertTrue(keep.delegates(userA, id) == userA);

        assertTrue(keep.getCurrentVotes(userA, id) == 0);
        assertTrue(keep.getVotes(userA, id) == 0);

        assertTrue(keep.getCurrentVotes(userB, id) == amount);
        assertTrue(keep.getVotes(userB, id) == amount);

        assertTrue(
            keep.getPriorVotes(userA, id, block.timestamp - 1) == amount
        );
        assertTrue(keep.getPastVotes(userA, id, block.timestamp - 1) == amount);

        vm.warp(1665378015);

        assertTrue(keep.getPriorVotes(userA, id, block.timestamp - 1) == 0);
        assertTrue(keep.getPastVotes(userA, id, block.timestamp - 1) == 0);

        assertTrue(
            keep.getPriorVotes(userB, id, block.timestamp - 1) == amount
        );
        assertTrue(keep.getPastVotes(userB, id, block.timestamp - 1) == amount);
    }

    /// @dev Test metaTXs.

    bytes32 constant PERMIT_TYPEHASH =
        keccak256(
            "Permit(address owner,address operator,bool approved,uint256 nonce,uint256 deadline)"
        );

    bytes32 constant DELEGATION_TYPEHASH =
        keccak256(
            "Delegation(address delegatee,uint256 nonce,uint256 deadline,uint256 id)"
        );

    function testKeepTokenPermit(
        address userB,
        bool approved,
        uint256 id,
        uint256 amount
    ) public payable {
        amount = bound(amount, 0, type(uint216).max);
        vm.assume(userB != address(0));
        vm.assume(userB.code.length == 0);

        uint256 privateKey = 0xBEEF;
        address userA = vm.addr(0xBEEF);

        vm.startPrank(address(keep));
        keep.mint(userA, id, amount, "");
        keep.setTransferability(id, true);
        assertTrue(keep.transferable(id));
        vm.stopPrank();

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

        assertTrue(keep.isApprovedForAll(userA, userB) == approved);
        assertEq(keep.nonces(userA), 1);
    }

    function testKeepTokenDelegateBySig(
        address userB,
        uint256 id,
        uint256 amount
    ) public payable {
        amount = bound(amount, 0, type(uint216).max);
        vm.assume(userB != address(0));
        vm.assume(userB.code.length == 0);

        uint256 privateKey = 0xBEEF;
        address userA = vm.addr(0xBEEF);

        startHoax(address(keep), address(keep), type(uint256).max);
        keep.mint(userA, id, amount, "");
        keep.setTransferability(id, true);
        assertTrue(keep.transferable(id));
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
                            userB,
                            0,
                            block.timestamp,
                            id
                        )
                    )
                )
            )
        );

        vm.startPrank(userA);
        keep.delegateBySig(userB, 0, block.timestamp, id, v, r, s);
        vm.stopPrank();

        assertTrue(keep.delegates(userA, id) == userB);
        assertEq(keep.nonces(userA), 1);
    }
}
