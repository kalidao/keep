// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {IClub} from '../interfaces/IClub.sol';

import {ClubLoot} from '../ClubLoot.sol';
import {Call, Signature, KaliClubSig} from '../KaliClubSig.sol';
import {KaliClubSigFactory} from '../KaliClubSigFactory.sol';

import '@std/Test.sol';

contract ClubNFTtest is Test {
    using stdStorage for StdStorage;

    ClubLoot loot;
    KaliClubSig clubSig;
    KaliClubSigFactory factory;

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

    bytes32 name =
        0x5445535400000000000000000000000000000000000000000000000000000000;
    bytes32 symbol =
        0x5445535400000000000000000000000000000000000000000000000000000000;

    /// -----------------------------------------------------------------------
    /// Club Setup Tests
    /// -----------------------------------------------------------------------

    /// @notice Set up the testing suite

    function setUp() public {
        loot = new ClubLoot();
        clubSig = new KaliClubSig();

        // Create the factory
        factory = new KaliClubSigFactory(loot, clubSig);

        // Create the calls
        Call[] memory calls = new Call[](0);

        // Create the Club[]
        IClub.Club[] memory clubs = new IClub.Club[](2);
        clubs[0] = alice > bob
            ? IClub.Club(bob, 1, 100)
            : IClub.Club(alice, 0, 100);
        clubs[1] = alice > bob
            ? IClub.Club(alice, 0, 100)
            : IClub.Club(bob, 1, 100);

        // The factory is fully tested in KaliClubSigFactory.t.sol
        (loot, clubSig) = factory.deployClubSig(
            calls,
            clubs,
            2,
            0,
            name,
            symbol,
            false,
            false,
            'BASE',
            'DOCS'
        );
    }

    /// -----------------------------------------------------------------------
    /// Club NFT Tests
    /// -----------------------------------------------------------------------

    function testApprove() public {
        startHoax(alice, alice, type(uint256).max);
        clubSig.approve(bob, 0);
        vm.stopPrank();
        assertEq(clubSig.getApproved(0), bob);
    }

    function testTransferFromByOwner() public {
        assertEq(clubSig.balanceOf(alice), 1);
        assertEq(clubSig.balanceOf(bob), 1);

        assertEq(clubSig.ownerOf(0), alice);
        assertEq(clubSig.ownerOf(1), bob);

        startHoax(bob, bob, type(uint256).max);
        vm.expectRevert(bytes4(keccak256('Forbidden()')));
        clubSig.transferFrom(alice, bob, 0);
        vm.stopPrank();

        startHoax(alice, alice, type(uint256).max);
        clubSig.transferFrom(alice, bob, 0);
        vm.stopPrank();

        assertEq(clubSig.balanceOf(alice), 0);
        assertEq(clubSig.balanceOf(bob), 2);

        assertEq(clubSig.ownerOf(0), bob);
        assertEq(clubSig.ownerOf(1), bob);
    }

    function testTransferFromByApprovedNonOwner() public {
        assertEq(clubSig.balanceOf(alice), 1);
        assertEq(clubSig.balanceOf(bob), 1);

        assertEq(clubSig.ownerOf(0), alice);
        assertEq(clubSig.ownerOf(1), bob);

        startHoax(bob, bob, type(uint256).max);
        vm.expectRevert(bytes4(keccak256('Forbidden()')));
        clubSig.transferFrom(alice, bob, 0);
        vm.stopPrank();

        startHoax(alice, alice, type(uint256).max);
        clubSig.approve(bob, 0);
        vm.stopPrank();
        assertEq(clubSig.getApproved(0), bob);

        startHoax(bob, bob, type(uint256).max);
        clubSig.transferFrom(alice, bob, 0);
        vm.stopPrank();

        assertEq(clubSig.balanceOf(alice), 0);
        assertEq(clubSig.balanceOf(bob), 2);

        assertEq(clubSig.ownerOf(0), bob);
        assertEq(clubSig.ownerOf(1), bob);
    }

    function testApprovedForAll() public {
        assertEq(clubSig.balanceOf(alice), 1);
        assertEq(clubSig.balanceOf(bob), 1);

        assertEq(clubSig.ownerOf(0), alice);
        assertEq(clubSig.ownerOf(1), bob);

        startHoax(bob, bob, type(uint256).max);
        vm.expectRevert(bytes4(keccak256('Forbidden()')));
        clubSig.transferFrom(alice, bob, 0);
        vm.stopPrank();

        startHoax(alice, alice, type(uint256).max);
        clubSig.setApprovalForAll(bob, true);
        assertTrue(clubSig.isApprovedForAll(alice, bob));
        vm.stopPrank();

        startHoax(bob, bob, type(uint256).max);
        clubSig.transferFrom(alice, bob, 0);
        vm.stopPrank();

        assertEq(clubSig.balanceOf(alice), 0);
        assertEq(clubSig.balanceOf(bob), 2);

        assertEq(clubSig.ownerOf(0), bob);
        assertEq(clubSig.ownerOf(1), bob);

        startHoax(alice, alice, type(uint256).max);
        clubSig.setApprovalForAll(bob, false);
        assertTrue(!clubSig.isApprovedForAll(alice, bob));
        vm.stopPrank();

        startHoax(bob, bob, type(uint256).max);
        clubSig.setApprovalForAll(alice, true);
        assertTrue(clubSig.isApprovedForAll(bob, alice));
        vm.stopPrank();

        startHoax(alice, alice, type(uint256).max);
        clubSig.safeTransferFrom(bob, alice, 0);
        clubSig.safeTransferFrom(bob, alice, 1, '');
        vm.stopPrank();

        assertEq(clubSig.balanceOf(alice), 2);
        assertEq(clubSig.balanceOf(bob), 0);

        assertEq(clubSig.ownerOf(0), alice);
        assertEq(clubSig.ownerOf(1), alice);
    }

    function testSafeTransferFromByOwner() public {
        assertEq(clubSig.balanceOf(alice), 1);
        assertEq(clubSig.balanceOf(bob), 1);

        assertEq(clubSig.ownerOf(0), alice);
        assertEq(clubSig.ownerOf(1), bob);

        startHoax(bob, bob, type(uint256).max);
        vm.expectRevert(bytes4(keccak256('Forbidden()')));
        clubSig.safeTransferFrom(alice, bob, 0);
        vm.stopPrank();

        startHoax(alice, alice, type(uint256).max);
        clubSig.safeTransferFrom(alice, bob, 0);
        vm.stopPrank();

        assertEq(clubSig.balanceOf(alice), 0);
        assertEq(clubSig.balanceOf(bob), 2);

        assertEq(clubSig.ownerOf(0), bob);
        assertEq(clubSig.ownerOf(1), bob);
    }

    function testSafeTransferFromByApprovedNonOwner() public {
        assertEq(clubSig.balanceOf(alice), 1);
        assertEq(clubSig.balanceOf(bob), 1);

        assertEq(clubSig.ownerOf(0), alice);
        assertEq(clubSig.ownerOf(1), bob);

        startHoax(bob, bob, type(uint256).max);
        vm.expectRevert(bytes4(keccak256('Forbidden()')));
        clubSig.safeTransferFrom(alice, bob, 0, '');
        vm.stopPrank();

        startHoax(alice, alice, type(uint256).max);
        clubSig.approve(bob, 0);
        vm.stopPrank();
        assertEq(clubSig.getApproved(0), bob);

        startHoax(bob, bob, type(uint256).max);
        clubSig.safeTransferFrom(alice, bob, 0, '');
        vm.stopPrank();

        assertEq(clubSig.balanceOf(alice), 0);
        assertEq(clubSig.balanceOf(bob), 2);

        assertEq(clubSig.ownerOf(0), bob);
        assertEq(clubSig.ownerOf(1), bob);
    }

    /*
    function testSafeTransferFromToContract() public {
        assertEq(clubSig.balanceOf(alice), 1);

        startHoax(alice, alice, type(uint256).max);
        clubSig.safeTransferFrom(alice, address(clubSig), 0);
        vm.stopPrank();
  
        startHoax(alice, alice, type(uint256).max);
        vm.expectRevert(bytes4(keccak256("InvalidRecipient()")));
        clubSig.safeTransferFrom(alice, address(loot), 0, "");
        vm.stopPrank();

        assertEq(clubSig.balanceOf(alice), 1);
    }

    function testSafeTransferFromToInvalidContract() public {
        assertEq(clubSig.balanceOf(alice), 1);

        startHoax(alice, alice, type(uint256).max);
        vm.expectRevert(bytes4(keccak256("InvalidRecipient()")));
        clubSig.safeTransferFrom(alice, address(loot), 0);
        vm.stopPrank();

        startHoax(alice, alice, type(uint256).max);
        vm.expectRevert(bytes4(keccak256("InvalidRecipient()")));
        clubSig.safeTransferFrom(alice, address(loot), 0, "");
        vm.stopPrank();

        assertEq(clubSig.balanceOf(alice), 1);
    }
    */
    function testPausedTransfer() public {
        startHoax(address(clubSig), address(clubSig), type(uint256).max);
        clubSig.setSignerPause(true);
        vm.stopPrank();
        assertTrue(clubSig.paused());

        assertEq(clubSig.balanceOf(alice), 1);

        startHoax(alice, alice, type(uint256).max);
        vm.expectRevert(bytes4(keccak256('Paused()')));
        clubSig.transferFrom(alice, bob, 0);
        vm.stopPrank();

        assertEq(clubSig.balanceOf(alice), 1);
    }
}
