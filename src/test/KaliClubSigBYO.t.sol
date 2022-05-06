// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {IClubBYO} from '../interfaces/IClubBYO.sol';
import {IRicardianLLC} from '../interfaces/IRicardianLLC.sol';

import {KaliClubSigBYO, Signature} from '../byo/KaliClubSigBYO.sol';
import {ClubLootBYO} from '../byo/ClubLootBYO.sol';
import {KaliClubSigBYOfactory} from '../byo/KaliClubSigBYOfactory.sol';

import {MockERC20} from '@solmate/test/utils/mocks/MockERC20.sol';
import {MockERC721} from '@solmate/test/utils/mocks/MockERC721.sol';

import '@std/Test.sol';

contract ClubSigBYOtest is Test {
    using stdStorage for StdStorage;

    KaliClubSigBYO clubSig;
    KaliClubSigBYO clubSigRepeat;
    ClubLootBYO loot;
    ClubLootBYO lootRepeat;
    KaliClubSigBYOfactory factory;
    MockERC20 mockDai;
    MockERC721 mockNFT;

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

    /// @dev Integrations

    IRicardianLLC public immutable ricardian =
        IRicardianLLC(0x2017d429Ad722e1cf8df9F1A2504D4711cDedC49);

    /// @dev Helpers

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
        clubSig = new KaliClubSigBYO();
        loot = new ClubLootBYO();
        mockDai = new MockERC20('Dai', 'DAI', 18);
        mockNFT = new MockERC721('NFT', 'NFT');

        // 1B mockDai!
        mockDai.mint(address(this), 1000000000 * 1e18);

        // mint some NFTs
        mockNFT.mint(alice, 0);
        mockNFT.mint(bob, 1);

        // Create the factory
        factory = new KaliClubSigBYOfactory(clubSig, loot, ricardian);

        // Create the Club[]
        IClubBYO.Club[] memory clubs = new IClubBYO.Club[](2);
        clubs[0] = alice > bob
            ? IClubBYO.Club(bob, 100)
            : IClubBYO.Club(alice, 100);
        clubs[1] = alice > bob
            ? IClubBYO.Club(alice, 100)
            : IClubBYO.Club(bob, 100);

        // The factory is fully tested in KaliClubSigBYOfactory.t.sol
        (clubSig, loot) = factory.deployClubSig(
            address(mockNFT),
            clubs,
            2,
            0,
            name,
            symbol,
            false,
            'DOCS'
        );

        mockDai.approve(address(clubSig), type(uint256).max);
    }

    /// @notice Check setup malconditions

    function testRepeatClubSetup() public {
        clubSigRepeat = new KaliClubSigBYO();
        // Create the Club[]
        IClubBYO.Club[] memory clubs = new IClubBYO.Club[](2);
        clubs[0] = alice > bob
            ? IClubBYO.Club(bob, 100)
            : IClubBYO.Club(alice, 100);
        clubs[1] = alice > bob
            ? IClubBYO.Club(alice, 100)
            : IClubBYO.Club(bob, 100);

        (clubSigRepeat, ) = factory.deployClubSig(
            address(mockNFT),
            clubs,
            2,
            0,
            name2,
            symbol2,
            false,
            'DOCS'
        );

        // Create the Club[]
        IClubBYO.Club[] memory clubsRepeat = new IClubBYO.Club[](2);
        clubsRepeat[0] = alice > bob
            ? IClubBYO.Club(bob, 100)
            : IClubBYO.Club(alice, 100);
        clubsRepeat[1] = alice > bob
            ? IClubBYO.Club(alice, 100)
            : IClubBYO.Club(bob, 100);

        vm.expectRevert(bytes4(keccak256('AlreadyInitialized()')));
        clubSigRepeat.init(2, 0, 'DOCS');
    }

    function testRepeatLootSetup() public {
        lootRepeat = new ClubLootBYO();
        // Create the Club[]
        IClubBYO.Club[] memory clubs = new IClubBYO.Club[](2);
        clubs[0] = alice > bob
            ? IClubBYO.Club(bob, 100)
            : IClubBYO.Club(alice, 100);
        clubs[1] = alice > bob
            ? IClubBYO.Club(alice, 100)
            : IClubBYO.Club(bob, 100);

        (, lootRepeat) = factory.deployClubSig(
            address(mockNFT),
            clubs,
            2,
            0,
            name2,
            symbol2,
            false,
            'DOCS'
        );

        vm.expectRevert(bytes4(keccak256('AlreadyInitialized()')));
        lootRepeat.init(alice, clubs, true);
    }

    function testZeroQuorumSetup() public {
        // Create the Club[]
        IClubBYO.Club[] memory clubs = new IClubBYO.Club[](2);
        clubs[0] = alice > bob
            ? IClubBYO.Club(bob, 100)
            : IClubBYO.Club(alice, 100);
        clubs[1] = alice > bob
            ? IClubBYO.Club(alice, 100)
            : IClubBYO.Club(bob, 100);

        vm.expectRevert(bytes(''));
        factory.deployClubSig(
            address(mockNFT),
            clubs,
            0,
            0,
            name2,
            symbol2,
            false,
            'DOCS'
        );
    }

    /// -----------------------------------------------------------------------
    /// Club State Tests
    /// -----------------------------------------------------------------------

    /*function testLoot() public view {
        assert(address(clubSig.loot()) == address(loot));
    }*/

    function testNonce() public view {
        assert(clubSig.nonce() == 1);
    }

    function testQuorum() public {
        assert(clubSig.quorum() == 2);

        vm.prank(address(clubSig));
        clubSig.setQuorum(3);
        assert(clubSig.quorum() == 3);
    }

    function testRedemptionStart() public {
        assert(clubSig.redemptionStart() == 0);
        startHoax(address(clubSig), address(clubSig), type(uint256).max);
        clubSig.setRedemptionStart(block.timestamp);
        vm.stopPrank();
        assert(clubSig.redemptionStart() == block.timestamp);
    }

    function testDocs() public {
        assert(keccak256(bytes(clubSig.docs())) == keccak256(bytes('DOCS')));
        string memory updated = 'NEW DOCS';

        startHoax(address(clubSig), address(clubSig), type(uint256).max);
        clubSig.setDocs(updated);
        vm.stopPrank();
        assert(keccak256(bytes(clubSig.docs())) == keccak256(bytes(updated)));
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

        Signature[] memory sigs = new Signature[](0);

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

        clubSig.execute(address(mockDai), 0, data, false, sigs);
        vm.stopPrank();
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

        vm.expectRevert(bytes4(keccak256('WrongSigner()')));
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

        vm.expectRevert(bytes4(keccak256('WrongSigner()')));
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

        vm.expectRevert(bytes4(keccak256('WrongSigner()')));
        // Execute tx
        clubSig.execute(address(mockDai), 0, tx_data, deleg, sigs);
    }

    /*
    function testExecuteWithNullSignatures(bool deleg) public {
        mockDai.transfer(address(clubSig), 100);
        address aliceAddress = alice;
        bytes memory tx_data = "";

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

        vm.expectRevert(bytes4(keccak256("WrongSigner()")));
        // Execute tx
        clubSig.execute(address(mockDai), 0, tx_data, deleg, sigs);
    }*/

    /// @notice Check governance

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

    /*
    function testSetLootPause(bool _paused) public {
        startHoax(address(clubSig), address(clubSig), type(uint256).max);
        clubSig.setLootPause(_paused);
        vm.stopPrank();
        assert(loot.paused() == _paused);
    }*/

    function testUpdateDocs(address dave) public {
        startHoax(dave, dave, type(uint256).max);
        vm.expectRevert(bytes4(keccak256('Forbidden()')));
        clubSig.setDocs('new_docs');
        vm.stopPrank();

        // The ClubSig itself should be able to update the docs
        startHoax(address(clubSig), address(clubSig), type(uint256).max);
        clubSig.setDocs('new_docs');
        vm.stopPrank();
        assertEq(
            keccak256(bytes('new_docs')),
            keccak256(bytes(clubSig.docs()))
        );
    }

    /// -----------------------------------------------------------------------
    /// Asset Management Tests
    /// -----------------------------------------------------------------------

    /// @notice Check treasury redemption
    /*
    function testRageQuit() public {
        address a = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
        address b = address(mockDai);

        address[] memory assets = new address[](2);
        assets[0] = a > b ? b : a;
        assets[1] = a > b ? a : b;

        mockDai.transfer(address(clubSig), 100000 * 1e18);

        (bool sent, ) = address(clubSig).call{value: 5 ether}("");
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
    }*/
}
