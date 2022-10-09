// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {ERC1155TokenReceiver, Operation, Call, Signature, Keep} from "../src/Keep.sol";
import {KeepFactory} from "../src/KeepFactory.sol";

import {MockERC20} from "@solbase/test/utils/mocks/MockERC20.sol";
import {MockERC721} from "@solbase/test/utils/mocks/MockERC721.sol";
import {MockERC1155} from "@solbase/test/utils/mocks/MockERC1155.sol";
import {MockERC1271Wallet} from "@solbase/test/utils/mocks/MockERC1271Wallet.sol";

import "@std/Test.sol";

contract KeepTest is Test, ERC1155TokenReceiver {
    using stdStorage for StdStorage;

    address keepAddr;
    address keepAddrRepeat;
    Keep keep;
    Keep keepRepeat;
    KeepFactory factory;
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
        keep = new Keep(Keep(alice));
        mockDai = new MockERC20("Dai", "DAI", 18);
        mockNFT = new MockERC721("NFT", "NFT");
        mock1155 = new MockERC1155();
        mockERC1271Wallet = new MockERC1271Wallet(alice);
        chainId = block.chainid;

        // 1B mockDai!
        mockDai.mint(address(this), 1000000000 * 1e18);

        mockNFT.mint(address(this), 1);

        mock1155.mint(address(this), 1, 1, "");

        // Create the factory.
        factory = new KeepFactory(keep);

        // Create the Signer[].
        address[] memory signers = new address[](2);
        signers[0] = alice > bob ? bob : alice;
        signers[1] = alice > bob ? alice : bob;

        keepAddr = factory.determineKeep(name);
        keep = Keep(keepAddr);
        // The factory is fully tested in KeepFactory.t.sol.
        factory.deployKeep(calls, signers, 2, name);
        EXECUTE_ID = uint32(keep.execute.selector);

        mockDai.approve(address(keep), type(uint256).max);
    }

    /// @notice Check setup malconditions.

    function testSignerSetup() public payable {
        assertTrue(keep.balanceOf(alice, EXECUTE_ID) == 1);
        assertTrue(keep.balanceOf(bob, EXECUTE_ID) == 1);
        assertTrue(keep.balanceOf(charlie, EXECUTE_ID) == 0);

        assertTrue(keep.totalSupply(EXECUTE_ID) == 2);
        assertTrue(keep.totalSupply(42069) == 0);
    }

    function testRepeatKeepSetup() public payable {
        keepRepeat = new Keep(Keep(alice));

        // Create the Signer[].
        address[] memory signers = new address[](2);
        signers[0] = alice > bob ? bob : alice;
        signers[1] = alice > bob ? alice : bob;

        keepAddrRepeat = factory.determineKeep(name2);
        keepRepeat = Keep(keepAddrRepeat);
        factory.deployKeep(calls, signers, 2, name2);

        vm.expectRevert(bytes4(keccak256("AlreadyInit()")));
        keepRepeat.initialize(calls, signers, 2);
    }

    function testZeroQuorumSetup() public payable {
        // Create the Signer[].
        address[] memory signers = new address[](2);
        signers[0] = alice > bob ? bob : alice;
        signers[1] = alice > bob ? alice : bob;

        vm.expectRevert(bytes(""));
        factory.deployKeep(calls, signers, 0, name2);
    }

    function testExcessiveQuorumSetup() public payable {
        // Create the Signer[].
        address[] memory signers = new address[](2);
        signers[0] = alice > bob ? bob : alice;
        signers[1] = alice > bob ? alice : bob;

        vm.expectRevert(bytes4(keccak256("QuorumOverSupply()")));
        factory.deployKeep(calls, signers, 3, name2);
    }

    function testOutOfOrderSignerSetup() public payable {
        // Create the Signer[].
        address[] memory signers = new address[](2);
        signers[0] = alice > bob ? alice : bob;
        signers[1] = alice > bob ? bob : alice;

        vm.expectRevert(bytes4(keccak256("InvalidSig()")));
        factory.deployKeep(calls, signers, 2, name2);
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
        assertEq(
            keep._initialChainId(),
            block.chainid
        );
    }*/

    function testQuorum() public payable {
        assert(keep.quorum() == 2);
        assert(keep.totalSupply(EXECUTE_ID) == 2);

        vm.prank(address(keep));
        keep.mint(charlie, EXECUTE_ID, 1, "");
        vm.stopPrank();

        assert(keep.totalSupply(EXECUTE_ID) == 3);

        vm.prank(address(keep));
        keep.setQuorum(3);
        vm.stopPrank();

        assert(keep.quorum() == 3);
    }

    function testTotalSignerSupply() public view {
        assert(keep.totalSupply(EXECUTE_ID) == 2);
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

    function testKeepERC1155FailOnZeroAddress() public payable {
        address local = address(this);
        vm.prank(address(keep));
        keep.mint(local, 2, 1, "");
        vm.stopPrank();

        vm.prank(address(keep));
        keep.setTransferability(2, true);
        vm.stopPrank();

        vm.expectRevert(bytes4(keccak256("InvalidRecipient()")));
        keep.safeTransferFrom(address(this), address(0), 2, 1, "");
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

    function testExecuteFailWithImproperSignatures() public payable {
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

    function testExecuteFailWithSignaturesOutOfOrder() public payable {
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

    function testExecuteFailWithSignaturesRepeated() public payable {
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

    function testExecuteFailWithNullSignatures() public payable {
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

    function testMint() public payable {
        assert(keep.totalSupply(EXECUTE_ID) == 2);

        startHoax(address(keep), address(keep), type(uint256).max);
        keep.mint(charlie, EXECUTE_ID, 1, "");
        vm.stopPrank();

        assert(keep.balanceOf(charlie, EXECUTE_ID) == 1);

        assert(keep.totalSupply(EXECUTE_ID) == 3);
        assert(keep.quorum() == 2);
    }

    function testMintFailZeroAddress() public payable {
        assert(keep.totalSupply(EXECUTE_ID) == 2);

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

        assert(keep.totalSupply(EXECUTE_ID) == 2);
        assert(keep.quorum() == 2);
    }

    function testBurn() public {
        startHoax(address(keep), address(keep), type(uint256).max);
        keep.setQuorum(1);
        vm.stopPrank();

        assertTrue(keep.balanceOf(alice, EXECUTE_ID) == 1);

        vm.prank(address(keep));
        keep.burn(alice, EXECUTE_ID, 1);
        vm.stopPrank();

        assert(keep.totalSupply(EXECUTE_ID) == 1);
        assert(keep.quorum() == 1);
    }

    function testRole() public payable {
        startHoax(charlie, charlie, type(uint256).max);
        vm.expectRevert(bytes4(keccak256("NotAuthorized()")));
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

    function testSetTransferability(address dave, uint256 id) public payable {
        // Non-keep itself should not be able to flip pause.
        startHoax(dave, dave, type(uint256).max);
        vm.expectRevert(bytes4(keccak256("NotAuthorized()")));
        keep.setTransferability(id, true);
        vm.stopPrank();
        assertTrue(!keep.transferable(id));

        // The keep itself should be able to flip pause.
        startHoax(address(keep), address(keep), type(uint256).max);
        keep.setTransferability(id, true);
        vm.stopPrank();
        assertTrue(keep.transferable(id) == true);

        startHoax(address(keep), address(keep), type(uint256).max);
        keep.mint(charlie, id, 1, "");
        vm.stopPrank();

        startHoax(charlie, charlie, type(uint256).max);
        keep.safeTransferFrom(charlie, alice, id, 1, "");
        vm.stopPrank();

        startHoax(address(keep), address(keep), type(uint256).max);
        keep.setTransferability(id, false);
        vm.stopPrank();
        assertTrue(!keep.transferable(id));

        startHoax(alice, alice, type(uint256).max);
        vm.expectRevert(bytes4(keccak256("NonTransferable()")));
        keep.safeTransferFrom(alice, charlie, id, 1, "");
        vm.stopPrank();
    }

    function testSetURI(address dave) public payable {
        startHoax(dave, dave, type(uint256).max);
        vm.expectRevert(bytes4(keccak256("NotAuthorized()")));
        keep.setURI(0, "new_base_uri");
        vm.stopPrank();

        // The keep itself should be able to update the base uri.
        startHoax(address(keep), address(keep), type(uint256).max);
        keep.setURI(0, "new_base_uri");
        vm.stopPrank();
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

    function testKeepTokenTransferByOwner(uint256 id) public payable {
        startHoax(address(keep), address(keep), type(uint256).max);
        keep.setTransferability(id, true);
        vm.stopPrank();
        assertTrue(keep.transferable(id) == true);

        startHoax(address(keep), address(keep), type(uint256).max);
        keep.mint(charlie, id, 1, "");
        vm.stopPrank();

        startHoax(charlie, charlie, type(uint256).max);
        keep.safeTransferFrom(charlie, bob, id, 1, "");
        vm.stopPrank();

        assertTrue(keep.balanceOf(charlie, id) == 0);
        assertTrue(keep.balanceOf(bob, id) == 1);
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
        startHoax(address(keep), address(keep), type(uint256).max);
        keep.setTransferability(id, true);
        vm.stopPrank();
        assertTrue(keep.transferable(id) == true);

        startHoax(charlie, charlie, type(uint256).max);
        keep.setApprovalForAll(alice, true);
        vm.stopPrank();
        assertTrue(keep.isApprovedForAll(charlie, alice));

        startHoax(address(keep), address(keep), type(uint256).max);
        keep.mint(charlie, id, 1, "");
        vm.stopPrank();

        startHoax(alice, alice, type(uint256).max);
        keep.safeTransferFrom(charlie, bob, id, 1, "");
        vm.stopPrank();

        assertTrue(keep.balanceOf(charlie, id) == 0);
        assertTrue(keep.balanceOf(bob, id) == 1);
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

    function testKeepTokenTransferFailNonTransferable(uint256 id)
        public
        payable
    {
        startHoax(charlie, charlie, type(uint256).max);
        keep.setApprovalForAll(alice, true);
        vm.stopPrank();
        assertTrue(keep.isApprovedForAll(charlie, alice));

        startHoax(address(keep), address(keep), type(uint256).max);
        keep.mint(charlie, id, 1, "");
        vm.stopPrank();

        startHoax(charlie, charlie, type(uint256).max);
        vm.expectRevert(bytes4(keccak256("NonTransferable()")));
        keep.safeTransferFrom(charlie, bob, id, 1, "");
        vm.stopPrank();

        startHoax(alice, alice, type(uint256).max);
        vm.expectRevert(bytes4(keccak256("NonTransferable()")));
        keep.safeTransferFrom(charlie, bob, id, 1, "");
        vm.stopPrank();

        assertTrue(keep.balanceOf(charlie, id) == 1);
        assertTrue(keep.balanceOf(bob, id) == 0);
    }

    function testKeepTokenBatchTransferFailNonTransferable() public payable {
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
}
