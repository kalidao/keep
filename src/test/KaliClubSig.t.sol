// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {IMember} from '../interfaces/IMember.sol';

import {ClubLoot} from '../ClubLoot.sol';
import {Call, Signature, KaliClubSig} from '../KaliClubSig.sol';
import {KaliClubSigFactory} from '../KaliClubSigFactory.sol';

import {MockERC20} from '@solmate/test/utils/mocks/MockERC20.sol';

import '@std/Test.sol';

contract ClubSigTest is Test {
    using stdStorage for StdStorage;

    ClubLoot loot;
    ClubLoot lootRepeat;
    KaliClubSig clubSig;
    KaliClubSig clubSigRepeat;
    KaliClubSigFactory factory;
    MockERC20 mockDai;

    /// @dev Users

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

    /// @dev Helpers

    Call[] calls;

    uint256 chainId;

    bytes32 name =
        0x5445535400000000000000000000000000000000000000000000000000000000;
    bytes32 symbol =
        0x5445535400000000000000000000000000000000000000000000000000000000;

    bytes32 name2 =
        0x5445535432000000000000000000000000000000000000000000000000000000;
    bytes32 symbol2 =
        0x5445535432000000000000000000000000000000000000000000000000000000;

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
        uint256 pk,
        address to,
        uint256 value,
        bytes memory data,
        bool deleg
    ) internal returns (Signature memory sig) {
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            pk,
            clubSig.getDigest(address(to), value, data, deleg, clubSig.nonce())
        );
        // set 'wrong v' to return null signer for tests
        if (pk == nullPk) v = 17;

        sig = Signature({v: v, r: r, s: s});
    }

    /// -----------------------------------------------------------------------
    /// Club Setup Tests
    /// -----------------------------------------------------------------------

    /// @notice Set up the testing suite

    function setUp() public {
        loot = new ClubLoot();
        clubSig = new KaliClubSig();
        mockDai = new MockERC20('Dai', 'DAI', 18);
        chainId = block.chainid;

        // 1B mockDai!
        mockDai.mint(address(this), 1000000000 * 1e18);

        // Create the factory
        factory = new KaliClubSigFactory(loot, clubSig);

        // Create the Member[]
        IMember.Member[] memory members = new IMember.Member[](2);
        members[0] = alice > bob
            ? IMember.Member(bob, 1, 100)
            : IMember.Member(alice, 0, 100);
        members[1] = alice > bob
            ? IMember.Member(alice, 0, 100)
            : IMember.Member(bob, 1, 100);

        // The factory is fully tested in KaliClubSigFactory.t.sol
        (loot, clubSig) = factory.deployClubSig(
            calls,
            members,
            2,
            0,
            name,
            symbol,
            false,
            false,
            'BASE'
        );

        mockDai.approve(address(clubSig), type(uint256).max);
    }

    /// @notice Check setup malconditions

    function testRepeatClubSetup() public {
        clubSigRepeat = new KaliClubSig();
        // Create the Member[]
        IMember.Member[] memory members = new IMember.Member[](2);
        members[0] = alice > bob
            ? IMember.Member(bob, 1, 100)
            : IMember.Member(alice, 0, 100);
        members[1] = alice > bob
            ? IMember.Member(alice, 0, 100)
            : IMember.Member(bob, 1, 100);

        ( , clubSigRepeat) = factory.deployClubSig(
            calls,
            members,
            2,
            0,
            name2,
            symbol2,
            false,
            false,
            'BASE'
        );

        // Create the Member[]
        IMember.Member[] memory clubsRepeat = new IMember.Member[](2);
        clubsRepeat[0] = alice > bob
            ? IMember.Member(bob, 3, 100)
            : IMember.Member(alice, 2, 100);
        clubsRepeat[1] = alice > bob
            ? IMember.Member(alice, 2, 100)
            : IMember.Member(bob, 3, 100);

        vm.expectRevert(bytes4(keccak256('AlreadyInitialized()')));
        clubSigRepeat.init(calls, clubsRepeat, 2, 0, false, 'BASE');
    }

    function testRepeatLootSetup() public {
        lootRepeat = new ClubLoot();
        // Create the Member[]
        IMember.Member[] memory members = new IMember.Member[](2);
        members[0] = alice > bob
            ? IMember.Member(bob, 1, 100)
            : IMember.Member(alice, 0, 100);
        clubs[1] = alice > bob
            ? IMember.Member(alice, 0, 100)
            : IMember.Member(bob, 1, 100);

        (lootRepeat, ) = factory.deployClubSig(
            calls,
            members,
            2,
            0,
            name2,
            symbol2,
            false,
            false,
            'BASE'
        );

        vm.expectRevert(bytes4(keccak256('AlreadyInitialized()')));
        lootRepeat.init(alice, clubs, true);
    }

    function testZeroQuorumSetup() public {
        // Create the Member[]
        IMember.Member[] memory members = new IMember.Member[](2);
        members[0] = alice > bob
            ? IMember.Member(bob, 1, 100)
            : IMember.Member(alice, 0, 100);
        members[1] = alice > bob
            ? IMember.Member(alice, 0, 100)
            : IMember.Member(bob, 1, 100);

        vm.expectRevert(bytes(''));
        factory.deployClubSig(
            calls,
            members,
            0,
            0,
            name2,
            symbol2,
            false,
            false,
            'BASE'
        );
    }

    function testExcessiveQuorumSetup() public {
        // Create the Member[]
        IMember.Member[] memory members = new IMember.Member[](2);
        members[0] = alice > bob
            ? IMember.Member(bob, 1, 100)
            : IMember.Member(alice, 0, 100);
        clubs[1] = alice > bob
            ? IMember.Member(alice, 0, 100)
            : IMember.Member(bob, 1, 100);

        vm.expectRevert(bytes4(keccak256('QuorumExceedsSigs()')));
        factory.deployClubSig(
            calls,
            members,
            3,
            0,
            name2,
            symbol2,
            false,
            false,
            'BASE'
        );
    }

    function testOutOfOrderSignerSetup() public {
        // Create the Member[]
        IMember.Member[] memory members = new IMember.Member[](2);
        members[0] = alice > bob
            ? IMember.Member(alice, 0, 100)
            : IMember.Member(bob, 1, 100);
        members[1] = alice > bob
            ? IMember.Member(bob, 1, 100)
            : IMember.Member(alice, 0, 100);

        vm.expectRevert(bytes4(keccak256('BadSigner()')));
        factory.deployClubSig(
            calls,
            members,
            2,
            0,
            name2,
            symbol2,
            false,
            false,
            'BASE'
        );
    }

    /// -----------------------------------------------------------------------
    /// Club State Tests
    /// -----------------------------------------------------------------------

    function testLoot() public view {
        assert(address(clubSig.loot()) == address(loot));
    }

    function testNonce() public view {
        assert(clubSig.nonce() == 1);
    }

    function testQuorum() public {
        assert(clubSig.quorum() == 2);
        address db = address(0xdeadbeef);

        IClub.Club[] memory clubs = new IClub.Club[](1);
        clubs[0] = IClub.Club(db, 2, 100);

        bool[] memory mints = new bool[](1);
        mints[0] = true;

        vm.prank(address(clubSig));
        clubSig.govern(clubs, mints, 3);

        assert(clubSig.quorum() == 3);
    }

    function testRedemptionStart() public {
        assert(clubSig.redemptionStart() == 0);
        startHoax(address(clubSig), address(clubSig), type(uint256).max);
        clubSig.setRedemptionStart(block.timestamp);
        vm.stopPrank();
        assert(clubSig.redemptionStart() == block.timestamp);
    }

    function testTotalSupply() public view {
        assert(clubSig.totalSupply() == 2);
    }

    function testClubName() public {
        assertEq(clubSig.name(), string(abi.encodePacked(name)));
    }

    function testClubSymbol() public {
        assertEq(clubSig.symbol(), string(abi.encodePacked(symbol)));
    }

    function testBaseURI() public {
        assert(
            keccak256(bytes(clubSig.tokenURI(1))) == keccak256(bytes('BASE'))
        );

        string memory updated = 'NEW BASE';
        startHoax(address(clubSig), address(clubSig), type(uint256).max);
        clubSig.setURI(updated);
        vm.stopPrank();
        assert(
            keccak256(bytes(clubSig.tokenURI(1))) == keccak256(bytes(updated))
        );
    }

    function testTokenURI() public {
        assert(
            keccak256(bytes(clubSig.tokenURI(1))) == keccak256(bytes('BASE'))
        );
        string memory updated = 'NEW BASE';

        startHoax(address(clubSig), address(clubSig), type(uint256).max);
        clubSig.setURI(updated);
        vm.stopPrank();
        assert(
            keccak256(bytes(clubSig.tokenURI(1))) == keccak256(bytes(updated))
        );
    }

    /// -----------------------------------------------------------------------
    /// Operations Tests
    /// -----------------------------------------------------------------------

    /// @notice Check execution

    function testExecuteGovernor() public {
        uint256 nonceInit = clubSig.nonce();
        startHoax(address(clubSig), address(clubSig), type(uint256).max);
        clubSig.setGovernor(alice, true);
        vm.stopPrank();
        assertTrue(clubSig.governor(alice));

        address aliceAddress = address(alice);

        mockDai.transfer(address(clubSig), 100);

        startHoax(address(alice), address(alice), type(uint256).max);

        bytes memory data = '';

        assembly {
            mstore(add(data, 0x20), shl(0xE0, 0xa9059cbb)) // transfer(address,uint256)
            mstore(add(data, 0x24), aliceAddress)
            mstore(add(data, 0x44), 100)
            mstore(data, 0x44)
            // Update free memory pointer
            mstore(0x40, add(data, 0x100))
        }

        Call[] memory call = new Call[](1);

        call[0].to = address(mockDai);
        call[0].value = 0;
        call[0].data = data;
        call[0].deleg = false;

        clubSig.batchExecute(call);
        vm.stopPrank();
        assert(mockDai.balanceOf(alice) == 100);
        uint256 nonceAfter = clubSig.nonce();
        assert((nonceInit + 1) == nonceAfter);
    }

    function testExecuteWithSignatures(bool deleg) public {
        mockDai.transfer(address(clubSig), 100);
        address aliceAddress = alice;
        bytes memory tx_data = '';

        if (!deleg) {
            assembly {
                mstore(add(tx_data, 0x20), shl(0xE0, 0xa9059cbb)) // transfer(address,uint256)
                mstore(add(tx_data, 0x24), aliceAddress)
                mstore(add(tx_data, 0x44), 100)
                mstore(tx_data, 0x44)
                // Update free memory pointer
                mstore(0x40, add(tx_data, 0x80))
            }
        } else {
            assembly {
                mstore(add(tx_data, 0x20), shl(0xE0, 0x70a08231)) // balanceOf(address)
                mstore(add(tx_data, 0x24), aliceAddress)
                mstore(tx_data, 0x24)
                // Update free memory pointer
                mstore(0x40, add(tx_data, 0x60))
            }
        }

        Signature[] memory sigs = new Signature[](2);

        Signature memory aliceSig;
        Signature memory bobSig;

        aliceSig = signExecution(alicesPk, address(mockDai), 0, tx_data, deleg);
        bobSig = signExecution(bobsPk, address(mockDai), 0, tx_data, deleg);

        sigs[0] = alice > bob ? bobSig : aliceSig;
        sigs[1] = alice > bob ? aliceSig : bobSig;

        // Execute tx
        clubSig.execute(address(mockDai), 0, tx_data, deleg, sigs);
    }

    /// @notice Check execution malconditions

    function testExecuteWithImproperSignatures(bool deleg) public {
        mockDai.transfer(address(clubSig), 100);
        address aliceAddress = alice;
        bytes memory tx_data = '';

        if (!deleg) {
            assembly {
                mstore(add(tx_data, 0x20), shl(0xE0, 0xa9059cbb)) // transfer(address,uint256)
                mstore(add(tx_data, 0x24), aliceAddress)
                mstore(add(tx_data, 0x44), 100)
                mstore(tx_data, 0x44)
                // Update free memory pointer
                mstore(0x40, add(tx_data, 0x80))
            }
        } else {
            assembly {
                mstore(add(tx_data, 0x20), shl(0xE0, 0x70a08231)) // balanceOf(address)
                mstore(add(tx_data, 0x24), aliceAddress)
                mstore(tx_data, 0x24)
                // Update free memory pointer
                mstore(0x40, add(tx_data, 0x60))
            }
        }

        Signature[] memory sigs = new Signature[](2);

        Signature memory aliceSig;
        Signature memory charlieSig;

        aliceSig = signExecution(alicesPk, address(mockDai), 0, tx_data, deleg);
        charlieSig = signExecution(
            charliesPk,
            address(mockDai),
            0,
            tx_data,
            deleg
        );

        sigs[0] = alice > charlie ? charlieSig : aliceSig;
        sigs[1] = alice > charlie ? aliceSig : charlieSig;

        vm.expectRevert(bytes4(keccak256('BadSigner()')));
        // Execute tx
        clubSig.execute(address(mockDai), 0, tx_data, deleg, sigs);
    }

    function testExecuteWithSignaturesOutOfOrder(bool deleg) public {
        mockDai.transfer(address(clubSig), 100);
        address aliceAddress = alice;
        bytes memory tx_data = '';

        if (!deleg) {
            assembly {
                mstore(add(tx_data, 0x20), shl(0xE0, 0xa9059cbb)) // transfer(address,uint256)
                mstore(add(tx_data, 0x24), aliceAddress)
                mstore(add(tx_data, 0x44), 100)
                mstore(tx_data, 0x44)
                // Update free memory pointer
                mstore(0x40, add(tx_data, 0x80))
            }
        } else {
            assembly {
                mstore(add(tx_data, 0x20), shl(0xE0, 0x70a08231)) // balanceOf(address)
                mstore(add(tx_data, 0x24), aliceAddress)
                mstore(tx_data, 0x24)
                // Update free memory pointer
                mstore(0x40, add(tx_data, 0x60))
            }
        }

        Signature[] memory sigs = new Signature[](2);

        Signature memory aliceSig;
        Signature memory bobSig;

        aliceSig = signExecution(alicesPk, address(mockDai), 0, tx_data, deleg);
        bobSig = signExecution(bobsPk, address(mockDai), 0, tx_data, deleg);

        sigs[0] = alice > bob ? aliceSig : bobSig;
        sigs[1] = alice > bob ? bobSig : aliceSig;

        vm.expectRevert(bytes4(keccak256('BadSigner()')));
        // Execute tx
        clubSig.execute(address(mockDai), 0, tx_data, deleg, sigs);
    }

    function testExecuteWithSignaturesRepeated(bool deleg) public {
        mockDai.transfer(address(clubSig), 100);
        address aliceAddress = alice;
        bytes memory tx_data = '';

        if (!deleg) {
            assembly {
                mstore(add(tx_data, 0x20), shl(0xE0, 0xa9059cbb)) // transfer(address,uint256)
                mstore(add(tx_data, 0x24), aliceAddress)
                mstore(add(tx_data, 0x44), 100)
                mstore(tx_data, 0x44)
                // Update free memory pointer
                mstore(0x40, add(tx_data, 0x80))
            }
        } else {
            assembly {
                mstore(add(tx_data, 0x20), shl(0xE0, 0x70a08231)) // balanceOf(address)
                mstore(add(tx_data, 0x24), aliceAddress)
                mstore(tx_data, 0x24)
                // Update free memory pointer
                mstore(0x40, add(tx_data, 0x60))
            }
        }

        Signature[] memory sigs = new Signature[](2);

        Signature memory aliceSig;

        aliceSig = signExecution(alicesPk, address(mockDai), 0, tx_data, deleg);

        sigs[0] = aliceSig;
        sigs[1] = aliceSig;

        vm.expectRevert(bytes4(keccak256('BadSigner()')));
        // Execute tx
        clubSig.execute(address(mockDai), 0, tx_data, deleg, sigs);
    }

    function testExecuteWithNullSignatures(bool deleg) public {
        mockDai.transfer(address(clubSig), 100);
        address aliceAddress = alice;
        bytes memory tx_data = '';

        if (!deleg) {
            assembly {
                mstore(add(tx_data, 0x20), shl(0xE0, 0xa9059cbb)) // transfer(address,uint256)
                mstore(add(tx_data, 0x24), aliceAddress)
                mstore(add(tx_data, 0x44), 100)
                mstore(tx_data, 0x44)
                // Update free memory pointer
                mstore(0x40, add(tx_data, 0x80))
            }
        } else {
            assembly {
                mstore(add(tx_data, 0x20), shl(0xE0, 0x70a08231)) // balanceOf(address)
                mstore(add(tx_data, 0x24), aliceAddress)
                mstore(tx_data, 0x24)
                // Update free memory pointer
                mstore(0x40, add(tx_data, 0x60))
            }
        }

        Signature[] memory sigs = new Signature[](2);

        Signature memory aliceSig;
        Signature memory nullSig;

        aliceSig = signExecution(alicesPk, address(mockDai), 0, tx_data, deleg);
        nullSig = signExecution(nullPk, address(mockDai), 0, tx_data, deleg);

        sigs[0] = alice > nully ? nullSig : aliceSig;
        sigs[1] = alice > nully ? aliceSig : nullSig;

        vm.expectRevert(bytes4(keccak256('BadSigner()')));
        // Execute tx
        clubSig.execute(address(mockDai), 0, tx_data, deleg, sigs);
    }

    /// @notice Check governance

    function testGovernAlreadyMinted() public {
        IMember.Member[] memory members = new IMember.Member[](1);
        members[0] = IMember.Member(alice, 0, 100);

        bool[] memory mints = new bool[](1);
        mints[0] = true;

        vm.expectRevert(bytes4(keccak256('AlreadyMinted()')));
        vm.prank(address(clubSig));
        clubSig.govern(members, mints, 3);
    }

    function testGovernMint() public {
        assert(clubSig.totalSupply() == 2);
        address db = address(0xdeadbeef);

        IMember.Member[] memory members = new IMember.Member[](1);
        members[0] = IMember.Member(db, 2, 100);

        bool[] memory mints = new bool[](1);
        mints[0] = true;

        vm.prank(address(clubSig));
        clubSig.govern(clubs, mints, 3);
        assert(clubSig.totalSupply() == 3);
        assert(clubSig.quorum() == 3);
        assert(loot.totalSupply() == 300);
    }

    function testGovernBurn() public {
        IMember.Member[] memory members = new IMember.Member[](1);
        members[0] = IMember.Member(alice, 1, 100);

        bool[] memory mints = new bool[](1);
        mints[0] = false;

        vm.prank(address(clubSig));
        clubSig.govern(members, mints, 1);
        assert(clubSig.totalSupply() == 1);
        assert(clubSig.quorum() == 1);
        assert(loot.totalSupply() == 100);
    }

    function testSetGovernor(address dave) public {
        startHoax(dave, dave, type(uint256).max);
        vm.expectRevert(bytes4(keccak256('Forbidden()')));
        clubSig.setGovernor(dave, true);
        vm.stopPrank();

        // The ClubSig itself should be able to flip governor
        startHoax(address(clubSig), address(clubSig), type(uint256).max);
        clubSig.setGovernor(dave, true);
        vm.stopPrank();
        assertTrue(clubSig.governor(dave));
    }

    function testSetSignerPause(address dave) public {
        startHoax(dave, dave, type(uint256).max);
        vm.expectRevert(bytes4(keccak256('Forbidden()')));
        clubSig.setSignerPause(true);
        vm.stopPrank();
        assertTrue(!clubSig.paused());

        // The ClubSig itself should be able to flip pause
        startHoax(address(clubSig), address(clubSig), type(uint256).max);
        clubSig.setSignerPause(true);
        vm.stopPrank();
        assertTrue(clubSig.paused());
    }

    function testSetLootPause(bool _paused) public {
        startHoax(address(clubSig), address(clubSig), type(uint256).max);
        clubSig.setLootPause(_paused);
        vm.stopPrank();
        assert(loot.paused() == _paused);
    }

    function testUpdateURI(address dave) public {
        startHoax(dave, dave, type(uint256).max);
        vm.expectRevert(bytes4(keccak256('Forbidden()')));
        clubSig.setURI('new_base_uri');
        vm.stopPrank();

        // The ClubSig itself should be able to update the base uri
        startHoax(address(clubSig), address(clubSig), type(uint256).max);
        clubSig.setURI('new_base_uri');
        vm.stopPrank();
        assertEq(
            keccak256(bytes('new_base_uri')),
            keccak256(bytes(clubSig.tokenURI(1)))
        );
    }

    /// -----------------------------------------------------------------------
    /// Asset Management Tests
    /// -----------------------------------------------------------------------

    /// @notice Check treasury redemption

    function testRageQuit() public {
        address a = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
        address b = address(mockDai);

        address[] memory assets = new address[](2);
        assets[0] = a > b ? b : a;
        assets[1] = a > b ? a : b;

        mockDai.transfer(address(clubSig), 100000 * 1e18);

        (bool sent, ) = address(clubSig).call{value: 5 ether}('');
        assert(sent);

        startHoax(alice, alice, 0);
        clubSig.ragequit(assets, 100);
        vm.stopPrank();

        uint256 aliceEthBal = address(alice).balance;
        uint256 aliceDaiBal = mockDai.balanceOf(address(alice));

        uint256 clubEthBal = address(clubSig).balance;
        uint256 clubDaiBal = mockDai.balanceOf(address(clubSig));

        assert(aliceEthBal == 2.5 ether);
        assert(aliceDaiBal == 50000 ether);

        assert(clubEthBal == 2.5 ether);
        assert(clubDaiBal == 50000 ether);
    }
}
