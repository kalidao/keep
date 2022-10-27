// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @dev Core.
import {ERC1155TokenReceiver, KeepToken, Operation, Call, Signature, Keep} from "../src/Keep.sol";
import {KeepFactory} from "../src/KeepFactory.sol";

/// @dev Extensions.
import {URIFetcher} from "../src/extensions/metadata/URIFetcher.sol";
import {URIRemoteFetcher} from "../src/extensions/metadata/URIRemoteFetcher.sol";

/// @dev Mocks.
import {MockERC20} from "@solbase/test/utils/mocks/MockERC20.sol";
import {MockERC721} from "@solbase/test/utils/mocks/MockERC721.sol";
import {MockERC1155} from "@solbase/test/utils/mocks/MockERC1155.sol";
import {MockERC1271Wallet} from "@solbase/test/utils/mocks/MockERC1271Wallet.sol";

/// @dev Test framework.
import "@std/Test.sol";

contract KeepTest is ERC1155TokenReceiver, Test {
    /// -----------------------------------------------------------------------
    /// Keep Test Storage
    /// -----------------------------------------------------------------------

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

    uint256 internal SIGNER_KEY;

    address[] signers;

    /// @dev Users.

    uint256 internal constant alicesPk =
        0x60b919c82f0b4791a5b7c6a7275970ace1748759ebdaa4076d7eeed9dbcff3c3;
    address public constant alice = 0x503408564C50b43208529faEf9bdf9794c015d52;

    uint256 internal constant bobsPk =
        0xf8f8a2f43c8376ccb0871305060d7b27b0554d2cc72bccf41b2705608452f315;
    address public constant bob = 0x001d3F1ef827552Ae1114027BD3ECF1f086bA0F9;

    uint256 internal constant charliesPk =
        0xb9dee2522aae4d21136ba441f976950520adf9479a3c0bda0a88ffc81495ded3;
    address public constant charlie =
        0xccc4A5CeAe4D88Caf822B355C02F9769Fb6fd4fd;

    uint256 internal constant nullPk =
        0x8b2ed20f3cc3dd482830910365cfa157e7568b9c3fa53d9edd3febd61086b9be;
    address public constant nully = 0x0ACDf2aC839B7ff4cd5F16e884B2153E902253f2;

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

        // Set 'wrong v' to return null signer for tests.
        if (pk == nullPk) v = 17;

        sig = Signature({user: user, v: v, r: r, s: s});
    }

    /// -----------------------------------------------------------------------
    /// Keep Setup Tests
    /// -----------------------------------------------------------------------

    /// @dev Set up the testing suite.

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
        mockDai.mint(address(this), 1_000_000_000 ether);
        // Mint mock 721.
        mockNFT.mint(address(this), 1);
        // Mint mock 1155.
        mock1155.mint(address(this), 1, 1, "");

        // Create the factory.
        factory = new KeepFactory(keep);

        // Create the Signer[] for setup.
        address[] memory setupSigners = new address[](2);
        setupSigners[0] = alice > bob ? bob : alice;
        setupSigners[1] = alice > bob ? alice : bob;

        // Store the signers for later.
        signers.push(alice > bob ? bob : alice);
        signers.push(alice > bob ? alice : bob);

        // Initialize Keep from factory.
        // The factory is fully tested in KeepFactory.t.sol.
        keepAddr = factory.determineKeep(name);
        keep = Keep(keepAddr);

        factory.deployKeep(name, calls, setupSigners, 2);

        // Store signer ID key.
        SIGNER_KEY = uint32(keep.execute.selector);

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
        keepRepeat = new Keep(Keep(address(uriFetcher)));

        keepAddrRepeat = factory.determineKeep(name2);
        keepRepeat = Keep(keepAddrRepeat);
        factory.deployKeep(name2, calls, signers, 2);

        vm.expectRevert(bytes4(keccak256("AlreadyInit()")));
        keepRepeat.initialize(calls, signers, 2);
    }

    function testCannotSetupWithZeroQuorum() public payable {
        vm.expectRevert(bytes4(keccak256("InvalidThreshold()")));
        factory.deployKeep(name2, calls, signers, 0);
    }

    function testCannotSetupWithExcessiveQuorum() public payable {
        vm.expectRevert(bytes4(keccak256("QuorumOverSupply()")));
        factory.deployKeep(name2, calls, signers, 3);
    }

    function testCannotSetupWithOutOfOrderSigners() public payable {
        address[] memory outOfOrderSigners = new address[](2);
        outOfOrderSigners[0] = alice > bob ? alice : bob;
        outOfOrderSigners[1] = alice > bob ? bob : alice;

        vm.expectRevert(bytes4(keccak256("InvalidSig()")));
        factory.deployKeep(name2, calls, outOfOrderSigners, 2);
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
        assert(keep.totalSupply(SIGNER_KEY) == 3);

        vm.prank(address(keep));
        keep.mint(charlie, SIGNER_KEY, 1, "");
        vm.stopPrank();

        assert(keep.totalSupply(SIGNER_KEY) == 4);

        vm.prank(address(keep));
        keep.setQuorum(3);
        vm.stopPrank();

        assert(keep.quorum() == 3);
    }

    function testTotalSignerSupply() public view {
        assert(keep.totalSupply(SIGNER_KEY) == 3);
    }

    /// -----------------------------------------------------------------------
    /// Keep Operations Tests
    /// -----------------------------------------------------------------------

    /// @dev Check receivers.

    function testReceiveETH() public payable {
        (bool sent, ) = address(keep).call{value: 5 ether}("");
        assert(sent);
    }

    function testReceiveERC721() public payable {
        mockNFT.safeTransferFrom(address(this), address(keep), 1);
        assert(mockNFT.ownerOf(1) == address(keep));
    }

    function testReceiveStandardERC1155() public payable {
        mock1155.safeTransferFrom(address(this), address(keep), 1, 1, "");
        assert(mock1155.balanceOf(address(keep), 1) == 1);
    }

    function testReceiveKeepERC1155() public payable {
        address local = address(this);

        startHoax(address(keep), address(keep), type(uint256).max);
        keep.mint(local, 2, 1, "");
        keep.setTransferability(2, true);
        vm.stopPrank();

        keep.safeTransferFrom(local, address(keep), 2, 1, "");
    }

    function testCannotTransferKeepERC1155ToZeroAddress() public payable {
        // Allow transferability.
        startHoax(address(keep), address(keep), type(uint256).max);
        keep.mint(alice, 2, 1, "");
        keep.setTransferability(2, true);
        vm.stopPrank();

        // Fail on zero address.
        startHoax(address(alice), address(alice), type(uint256).max);
        vm.expectRevert(bytes4(keccak256("InvalidRecipient()")));
        keep.safeTransferFrom(alice, address(0), 2, 1, "");
        // Success on non-zero address.
        keep.safeTransferFrom(alice, bob, 2, 1, "");
        vm.stopPrank();
    }

    /// @dev Check call execution.

    function testExecuteCallWithRole() public payable {
        uint256 nonceInit = keep.nonce();

        // Mint executor role.
        vm.prank(address(keep));
        keep.mint(alice, uint32(keep.multiExecute.selector), 1, "");
        vm.stopPrank();

        // Mock execution.
        startHoax(address(alice), address(alice), type(uint256).max);

        bytes memory data;

        assembly {
            mstore(add(data, 0x20), shl(0xE0, 0xa9059cbb)) // `transfer(address,uint256)`.
            mstore(add(data, 0x24), alice)
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
        bytes memory tx_data;

        assembly {
            mstore(add(tx_data, 0x20), shl(0xE0, 0xa9059cbb)) // `transfer(address,uint256)`.
            mstore(add(tx_data, 0x24), alice)
            mstore(add(tx_data, 0x44), 100)
            mstore(tx_data, 0x44)
            // Update free memory pointer.
            mstore(0x40, add(tx_data, 0x80))
        }

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

    function testExecuteDelegateCallWithSignatures() public payable {
        bytes memory tx_data;

        assembly {
            mstore(add(tx_data, 0x20), shl(0xE0, 0x70a08231)) // `balanceOf(address)`.
            mstore(add(tx_data, 0x24), alice)
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

    function testExecuteEthCallWithSignatures() public payable {
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

    function testExecuteCallWithContractSignatures() public payable {
        bytes memory tx_data;

        assembly {
            mstore(add(tx_data, 0x20), shl(0xE0, 0xa9059cbb)) // `transfer(address,uint256)`.
            mstore(add(tx_data, 0x24), alice)
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

        sigs[0] = bobSig;
        sigs[1] = aliceSig;

        // Execute tx.
        keep.execute(Operation.call, address(mockDai), 0, tx_data, sigs);
    }

    /// @dev Check execution errors.

    function testCannotExecuteWithImproperSignatures() public payable {
        bytes memory tx_data;

        assembly {
            mstore(add(tx_data, 0x20), shl(0xE0, 0xa9059cbb)) // `transfer(address,uint256)`.
            mstore(add(tx_data, 0x24), alice)
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

        vm.expectRevert(bytes4(keccak256("InvalidSig()")));
        // Execute tx.
        keep.execute(Operation.call, address(mockDai), 0, tx_data, sigs);
    }

    function testCannotExecuteWithSignaturesOutOfOrder() public payable {
        bytes memory tx_data;

        assembly {
            mstore(add(tx_data, 0x20), shl(0xE0, 0xa9059cbb)) // `transfer(address,uint256)`.
            mstore(add(tx_data, 0x24), alice)
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
        bytes memory tx_data;

        assembly {
            mstore(add(tx_data, 0x20), shl(0xE0, 0xa9059cbb)) // `transfer(address,uint256)`.
            mstore(add(tx_data, 0x24), alice)
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
        bytes memory tx_data;

        assembly {
            mstore(add(tx_data, 0x20), shl(0xE0, 0xa9059cbb)) // `transfer(address,uint256)`.
            mstore(add(tx_data, 0x24), alice)
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

        vm.expectRevert(bytes4(keccak256("InvalidSig()")));
        // Execute tx.
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

    function testCannotMintZeroAddress() public payable {
        assert(keep.totalSupply(SIGNER_KEY) == 3);

        startHoax(address(keep), address(keep), type(uint256).max);
        vm.expectRevert(bytes4(keccak256("InvalidRecipient()")));
        keep.mint(address(0), SIGNER_KEY, 1, "");
        vm.expectRevert(bytes4(keccak256("InvalidRecipient()")));
        keep.mint(address(0), 1, 1, "");
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

        vm.expectRevert(bytes4(keccak256("Overflow()")));
        keep.mint(charlie, 1, type(uint256).max, "");

        keep.mint(charlie, 2, type(uint216).max, "");

        vm.expectRevert(bytes4(keccak256("Overflow()")));
        keep.mint(charlie, 2, 1, "");

        vm.expectRevert(bytes4(keccak256("Overflow()")));
        keep.mint(charlie, 3, amount, "");

        vm.stopPrank();
    }

    function testCannotMintOverflowExecuteID() public payable {
        startHoax(address(keep), address(keep), type(uint256).max);

        keep.mint(charlie, SIGNER_KEY, 1, "");

        vm.expectRevert(bytes4(keccak256("Overflow()")));
        keep.mint(charlie, SIGNER_KEY, 1, "");

        keep.burn(charlie, SIGNER_KEY, 1);

        keep.mint(charlie, SIGNER_KEY, 1, "");

        vm.expectRevert(bytes4(keccak256("Overflow()")));
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
        vm.expectRevert(bytes4(keccak256("Unauthorized()")));
        keep.mint(alice, 1, 100, "");
        vm.stopPrank();

        vm.prank(address(keep));
        keep.mint(charlie, uint32(keep.mint.selector), 1, "");
        vm.stopPrank();

        vm.prank(charlie);
        keep.mint(alice, 1, 100, "");
        vm.stopPrank();

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
        vm.expectRevert(bytes4(keccak256("NonTransferable()")));
        keep.safeTransferFrom(alice, charlie, 1, 1, "");
        vm.stopPrank();
    }

    function testCannotSetTransferability(address user, uint256 id)
        public
        payable
    {
        vm.assume(user != address(keep));

        vm.prank(user);
        vm.expectRevert(bytes4(keccak256("Unauthorized()")));
        keep.setTransferability(id, true);
        vm.stopPrank();

        assertFalse(keep.transferable(id));
    }

    function testSetURI(address user) public payable {
        vm.assume(user != address(keep));

        vm.prank(user);
        vm.expectRevert(bytes4(keccak256("Unauthorized()")));
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

    function testKeepTokenApprove() public payable {
        vm.prank(alice);
        keep.setApprovalForAll(bob, true);
        vm.stopPrank();

        assertTrue(keep.isApprovedForAll(alice, bob));

        vm.prank(alice);
        keep.setApprovalForAll(bob, false);
        vm.stopPrank();

        assertFalse(keep.isApprovedForAll(alice, bob));
    }

    function testKeepTokenTransferByOwner(uint256 id, uint256 amount)
        public
        payable
    {
        vm.assume(id != SIGNER_KEY);
        amount = bound(amount, 0, type(uint216).max);

        vm.startPrank(address(keep));
        keep.setTransferability(id, true);
        keep.mint(charlie, id, amount, "");
        vm.stopPrank();

        uint256 charliePreBalance = keep.balanceOf(charlie, id);
        uint256 bobPreBalance = keep.balanceOf(bob, id);

        vm.prank(charlie);
        keep.safeTransferFrom(charlie, bob, id, amount, "");
        vm.stopPrank();

        assert(keep.balanceOf(charlie, id) == charliePreBalance - amount);
        assert(keep.balanceOf(bob, id) == bobPreBalance + amount);
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

    function testKeepTokenTransferByOperator(uint256 id) public payable {
        vm.assume(id != SIGNER_KEY);

        uint256 bobPreBalance = keep.balanceOf(bob, id);

        startHoax(address(keep), address(keep), type(uint256).max);
        keep.setTransferability(id, true);
        keep.mint(charlie, id, 1, "");
        vm.stopPrank();

        vm.prank(charlie);
        keep.setApprovalForAll(alice, true);
        vm.stopPrank();

        assertTrue(keep.isApprovedForAll(charlie, alice));

        vm.prank(alice);
        keep.safeTransferFrom(charlie, bob, id, 1, "");
        vm.stopPrank();

        assert(keep.balanceOf(charlie, id) == 0);
        assert(keep.balanceOf(bob, id) == bobPreBalance + 1);
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
        amount = bound(amount, 0, type(uint216).max);
        vm.assume(id != 2094031643); // Bad
        vm.assume(id != SIGNER_KEY);
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
        vm.expectRevert(bytes4(keccak256("NotPermitted()")));
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
        vm.expectRevert(bytes4(keccak256("NonTransferable()")));
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
        vm.expectRevert(bytes4(keccak256("Overflow()")));
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
        vm.expectRevert(bytes4(keccak256("NonTransferable()")));
        keep.safeTransferFrom(charlie, bob, id, 1, "");
        vm.stopPrank();

        assertTrue(keep.isApprovedForAll(charlie, alice));

        vm.prank(alice);
        vm.expectRevert(bytes4(keccak256("NonTransferable()")));
        keep.safeTransferFrom(charlie, bob, id, 1, "");
        vm.stopPrank();

        assert(keep.balanceOf(charlie, id) == charlieBalance);
        assert(keep.balanceOf(bob, id) == bobBalance);
    }

    function testCannotTransferKeepTokenNonTransferable() public payable {
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
        vm.expectRevert(bytes4(keccak256("NonTransferable()")));
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
        amount = bound(amount, 0, type(uint216).max);
        vm.assume(userA != address(0));
        vm.assume(userB != address(0));
        vm.assume(userA != userB);
        vm.assume(userA.code.length == 0);
        vm.assume(userB.code.length == 0);
        vm.assume(id != SIGNER_KEY);

        startHoax(address(keep), address(keep), type(uint256).max);
        keep.mint(userA, id, amount, "");
        keep.setTransferability(id, true);
        keep.setPermission(id, true);
        vm.stopPrank();

        assertTrue(keep.transferable(id));
        assertTrue(keep.permissioned(id));

        startHoax(userA, userA, type(uint256).max);
        vm.expectRevert(bytes4(keccak256("NotPermitted()")));
        keep.safeTransferFrom(userA, userB, id, amount, "");
        vm.stopPrank();

        assert(keep.balanceOf(userA, id) == amount);
        assert(keep.balanceOf(userB, id) == 0);
    }

    /// -----------------------------------------------------------------------
    /// Keep Vote Delegation Tests
    /// -----------------------------------------------------------------------

    function testKeepTokenInitDelegationBalance(
        address user,
        uint256 id,
        uint256 amount
    ) public payable {
        amount = bound(amount, 0, type(uint216).max);
        vm.assume(user != address(0));
        vm.assume(user.code.length == 0);
        vm.assume(id != SIGNER_KEY);

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

    bytes32 constant PERMIT_TYPEHASH =
        keccak256(
            "Permit(address owner,address operator,bool approved,uint256 nonce,uint256 deadline)"
        );

    bytes32 constant DELEGATION_TYPEHASH =
        keccak256(
            "Delegation(address delegatee,uint256 nonce,uint256 deadline,uint256 id)"
        );

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

        assert(keep.delegates(userA, id) == userB);
        assert(keep.nonces(userA) == 1);
    }
}
