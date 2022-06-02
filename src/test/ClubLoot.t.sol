// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {IClub} from '../interfaces/IClub.sol';

import {ClubLoot} from '../ClubLoot.sol';
import {Call, Signature, KaliClubSig} from '../KaliClubSig.sol';
import {KaliClubSigFactory} from '../KaliClubSigFactory.sol';

import '@std/Test.sol';

contract ClubLootTest is Test {
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

    bytes32 constant PERMIT_TYPEHASH =
        keccak256(
            'Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)'
        );

    function signPermit(uint256 pk, bytes32 digest)
        internal
        returns (
            uint8 v,
            bytes32 r,
            bytes32 s
        )
    {
        (v, r, s) = vm.sign(pk, digest);
    }

    /// -----------------------------------------------------------------------
    /// Club Setup Tests
    /// -----------------------------------------------------------------------

    /// @notice Set up the testing suite

    function setUp() public {
        loot = new ClubLoot();
        clubSig = new KaliClubSig();

        // Create the factory
        factory = new KaliClubSigFactory(loot, clubSig);

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
            'BASE'
        );
    }

    /// -----------------------------------------------------------------------
    /// Club Loot Tests
    /// -----------------------------------------------------------------------

    function testInvariantMetadata() public {
        assertEq(loot.name(), string(abi.encodePacked(name, ' LOOT')));
        assertEq(loot.symbol(), string(abi.encodePacked(symbol, '-LOOT')));
        assertEq(loot.decimals(), 18);
    }

    function testApprove() public {
        assertTrue(loot.approve(address(0xBEEF), 1e18));
        assertEq(loot.allowance(address(this), address(0xBEEF)), 1e18);
    }

    function testTransfer() public {
        startHoax(alice, alice, type(uint256).max);
        assertTrue(loot.transfer(address(0xBEEF), 10));
        vm.stopPrank();

        assertEq(loot.totalSupply(), 200);
        assertEq(loot.balanceOf(alice), 90);
        assertEq(loot.balanceOf(address(0xBEEF)), 10);
    }

    function testTransferFrom() public {
        startHoax(alice, alice, type(uint256).max);
        assertTrue(loot.approve(bob, 10));
        vm.stopPrank();

        assertEq(loot.allowance(alice, bob), 10);

        startHoax(bob, bob, type(uint256).max);
        assertTrue(loot.transferFrom(alice, charlie, 10));
        vm.stopPrank();

        assertEq(loot.allowance(alice, bob), 0);
        assertEq(loot.balanceOf(alice), 90);
        assertEq(loot.balanceOf(charlie), 10);
    }

    function testBurn() public {
        startHoax(bob, bob, type(uint256).max);
        loot.burn(10);
        vm.stopPrank();

        assertEq(loot.balanceOf(bob), 90);
        assert(loot.totalSupply() == 190);
    }

    function testBurnFrom() public {
        startHoax(alice, alice, type(uint256).max);
        assertTrue(loot.approve(bob, 10));
        vm.stopPrank();

        assertEq(loot.allowance(alice, bob), 10);

        startHoax(bob, bob, type(uint256).max);
        loot.burnFrom(alice, 10);
        vm.stopPrank();

        assertEq(loot.allowance(alice, bob), 0);
        assertEq(loot.balanceOf(alice), 90);
        assert(loot.totalSupply() == 190);
    }

    function testGovernance() public {
        assert(loot.governors(address(clubSig)));

        startHoax(alice, alice, type(uint256).max);
        vm.expectRevert(bytes4(keccak256('NotGov()')));
        loot.setGov(alice, true);
        vm.stopPrank();

        startHoax(address(clubSig), address(clubSig), type(uint256).max);
        loot.setGov(alice, true);
        vm.stopPrank();

        assert(loot.governors(alice));

        startHoax(alice, alice, type(uint256).max);
        loot.setGov(bob, true);
        vm.stopPrank();

        assert(loot.governors(address(clubSig)));
        assert(loot.governors(alice));
        assert(loot.governors(bob));
    }

    function testMint() public {
        address db = address(0xdeadbeef);

        IClub.Club[] memory clubs = new IClub.Club[](1);
        clubs[0] = IClub.Club(db, 2, 100);

        bool[] memory mints = new bool[](1);
        mints[0] = true;

        vm.prank(address(clubSig));
        clubSig.govern(clubs, mints, 3);
        assert(loot.balanceOf(db) == 100);
        assert(loot.totalSupply() == 300);

        vm.prank(address(clubSig));
        loot.mintShares(alice, 100);
        assert(loot.balanceOf(alice) == 200);
        assert(loot.totalSupply() == 400);
    }

    function testGovBurn() public {
        startHoax(address(clubSig), address(clubSig), type(uint256).max);
        loot.burnShares(alice, 50);
        assert(loot.balanceOf(alice) == 50);
        assert(loot.totalSupply() == 150);
        vm.stopPrank();
    }

    function testSetLootPause(bool _paused) public {
        startHoax(address(clubSig), address(clubSig), type(uint256).max);
        clubSig.setLootPause(_paused);
        vm.stopPrank();
        assert(loot.paused() == _paused);
    }

    function testPausedTransfer() public {
        startHoax(address(clubSig), address(clubSig), type(uint256).max);
        clubSig.setLootPause(true);
        vm.stopPrank();

        startHoax(alice, alice, type(uint256).max);
        vm.expectRevert(bytes4(keccak256('Paused()')));
        loot.transfer(address(0xBEEF), 10);
        vm.stopPrank();
    }

    function testPermit() public {
        (uint8 v, bytes32 r, bytes32 s) = signPermit(
            alicesPk,
            keccak256(
                abi.encodePacked(
                    '\x19\x01',
                    loot.DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            PERMIT_TYPEHASH,
                            alice,
                            address(0xCAFE),
                            1e18,
                            0,
                            block.timestamp
                        )
                    )
                )
            )
        );

        loot.permit(alice, address(0xCAFE), 1e18, block.timestamp, v, r, s);

        assertEq(loot.allowance(alice, address(0xCAFE)), 1e18);
        assertEq(loot.nonces(alice), 1);
    }

    function testGetCurrentVotes() public view {
        assert(loot.getCurrentVotes(alice) == 100);
        assert(loot.getCurrentVotes(bob) == 100);
        assert(loot.getCurrentVotes(charlie) == 0);
    }

    function testGetPriorVotes() public {
        vm.warp(block.timestamp + 2 days);
        assert(loot.getPriorVotes(alice, block.timestamp - 1 days) == 100);
        assert(loot.getPriorVotes(bob, block.timestamp - 1 days) == 100);
        assert(loot.getPriorVotes(charlie, block.timestamp - 1 days) == 0);
    }

    function testDelegation() public {
        assert(loot.delegates(alice) == alice);
        assert(loot.delegates(bob) == bob);

        startHoax(alice, alice, type(uint256).max);
        loot.delegate(bob);

        assert(loot.delegates(alice) == bob);
        assert(loot.getCurrentVotes(alice) == 0);
        assert(loot.getCurrentVotes(bob) == 200);

        vm.warp(block.timestamp + 2 days);

        assert(loot.getPriorVotes(alice, block.timestamp - 1 days) == 0);
        assert(loot.getPriorVotes(bob, block.timestamp - 1 days) == 200);
    }

    function testDelegationByTransfer() public {
        startHoax(alice, alice, type(uint256).max);
        assertTrue(loot.transfer(bob, 10));
        assert(loot.getCurrentVotes(alice) == 90);
        assert(loot.getCurrentVotes(bob) == 110);
        vm.warp(block.timestamp + 2 days);
        assert(loot.getPriorVotes(alice, block.timestamp - 1 days) == 90);
        assert(loot.getPriorVotes(bob, block.timestamp - 1 days) == 110);
    }

    function testDelegationByTransferFrom() public {
        startHoax(alice, alice, type(uint256).max);
        assertTrue(loot.approve(bob, 10));
        vm.stopPrank();

        assertEq(loot.allowance(alice, bob), 10);

        startHoax(bob, bob, type(uint256).max);
        assertTrue(loot.transferFrom(alice, charlie, 10));
        vm.stopPrank();

        assertEq(loot.allowance(alice, bob), 0);
        assertEq(loot.balanceOf(alice), 90);
        assertEq(loot.balanceOf(charlie), 10);

        assert(loot.getCurrentVotes(alice) == 90);
        assert(loot.getCurrentVotes(charlie) == 10);

        vm.warp(block.timestamp + 2 days);
        assert(loot.getPriorVotes(alice, block.timestamp - 1 days) == 90);
        assert(loot.getPriorVotes(charlie, block.timestamp - 1 days) == 10);
    }

    function testDelegationByMint() public {
        address db = address(0xdeadbeef);

        IClub.Club[] memory clubs = new IClub.Club[](1);
        clubs[0] = IClub.Club(db, 2, 100);

        bool[] memory mints = new bool[](1);
        mints[0] = true;

        vm.prank(address(clubSig));
        clubSig.govern(clubs, mints, 3);
        assert(loot.balanceOf(db) == 100);
        assert(loot.totalSupply() == 300);

        assert(loot.getCurrentVotes(db) == 100);

        vm.warp(block.timestamp + 2 days);
        assert(loot.getPriorVotes(db, block.timestamp - 1 days) == 100);

        vm.prank(address(clubSig));
        loot.mintShares(alice, 100);
        assert(loot.balanceOf(alice) == 200);
        assert(loot.totalSupply() == 400);

        assert(loot.getCurrentVotes(alice) == 200);

        vm.warp(block.timestamp + 2 days);
        assert(loot.getPriorVotes(alice, block.timestamp - 1 days) == 200);
    }

    function testDelegationByBurn() public {
        startHoax(bob, bob, type(uint256).max);
        loot.burn(10);
        vm.stopPrank();

        assertEq(loot.balanceOf(bob), 90);
        assert(loot.totalSupply() == 190);

        assert(loot.getCurrentVotes(bob) == 90);

        vm.warp(block.timestamp + 2 days);
        assert(loot.getPriorVotes(bob, block.timestamp - 1 days) == 90);
    }

    function testSafeCast192forVoteInit() public {
        KaliClubSig clubSig1 = new KaliClubSig();
        ClubLoot loot1 = new ClubLoot();

        // Create the factory
        factory = new KaliClubSigFactory(loot1, clubSig1);

        // Set mint amount
        uint256 tooBigMintAmount = (1 << 192) + 1;

        // Create the Club[]
        IClub.Club[] memory clubs = new IClub.Club[](2);
        clubs[0] = alice > bob
            ? IClub.Club(bob, 1, tooBigMintAmount)
            : IClub.Club(alice, 0, tooBigMintAmount);
        clubs[1] = alice > bob
            ? IClub.Club(alice, 0, tooBigMintAmount)
            : IClub.Club(bob, 1, tooBigMintAmount);

        vm.expectRevert(bytes4(keccak256('Uint192max()')));
        factory.deployClubSig(
            calls,
            clubs,
            2,
            0,
            name,
            symbol,
            false,
            false,
            'BASE'
        );
    }

    function testSafeCast192forVoteMint() public {
        uint256 tooBigMintAmount = (1 << 192) + 1;
        vm.prank(address(clubSig));
        vm.expectRevert(bytes4(keccak256('Uint192max()')));
        loot.mintShares(alice, tooBigMintAmount);
    }
}
