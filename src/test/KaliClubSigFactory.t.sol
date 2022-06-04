// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {IMember} from '../interfaces/IMember.sol';

import {ClubLoot} from '../ClubLoot.sol';
import {Call, KaliClubSig} from '../KaliClubSig.sol';
import {KaliClubSigFactory} from '../KaliClubSigFactory.sol';

import '@std/Test.sol';

contract KaliClubSigFactoryTest is Test {
    ClubLoot loot;
    KaliClubSig clubSig;
    KaliClubSigFactory factory;

    /// @dev Users

    address public immutable alice = address(0xa);
    address public immutable bob = address(0xb);

    /// @dev Helpers

    Call[] calls;

    bytes32 name =
        0x5445535400000000000000000000000000000000000000000000000000000000;
    bytes32 symbol =
        0x5445535400000000000000000000000000000000000000000000000000000000;

    bytes32 name2 =
        0x5445535432000000000000000000000000000000000000000000000000000000;
    bytes32 symbol2 =
        0x5445535432000000000000000000000000000000000000000000000000000000;

    /// @notice Set up the testing suite

    function setUp() public {
        // create the templates
        loot = new ClubLoot();
        clubSig = new KaliClubSig(KaliClubSig(alice));
        // create the factory
        factory = new KaliClubSigFactory(loot, clubSig);
    }

    function testDeployClubSig() public {
        KaliClubSig depClubSig;
        // create the Club[]
        IMember.Member[] memory members = new IMember.Member[](2);
        members[0] = IMember.Member(false, alice, 0, 100);
        members[1] = IMember.Member(false, bob, 1, 100);
        // vm.expectEmit(true, true, false, false);
        (, depClubSig) = factory.deployClubSig(
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
        // sanity check initialization
        assertEq(
            keccak256(bytes(depClubSig.tokenURI(1))),
            keccak256(bytes('BASE'))
        );
        assertEq(
            depClubSig.totalSupply(),
            2
        );
    }

    function testCloneAddressDetermination() public {
        ClubLoot depLoot;
        KaliClubSig depClubSig;
        // create the Club[]
        IMember.Member[] memory members = new IMember.Member[](2);
        members[0] = IMember.Member(false, alice, 0, 100);
        members[1] = IMember.Member(false, bob, 1, 100);
        // vm.expectEmit(true, true, false, false);
        (depLoot, depClubSig) = factory.deployClubSig(
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
        // check CREATE2 clones match expected outputs
        (address lootAddr, address clubAddr, bool deployed) = factory.determineClones(name, symbol);
        assertEq(
            address(depLoot),
            lootAddr
        );
        assertEq(
            address(depClubSig),
            clubAddr
        );
        assertEq(
            deployed,
            true
        );
        (, , bool deployed2) = factory.determineClones(name2, symbol2);
        assertEq(
            deployed2,
            false
        );
    }
}
