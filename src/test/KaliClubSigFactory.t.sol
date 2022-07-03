// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {IMember} from '../interfaces/IMember.sol';

import {Call, KaliClub} from '../KaliClub.sol';
import {KaliClubFactory} from '../KaliClubFactory.sol';

import '@std/Test.sol';

contract KaliClubSigFactoryTest is Test {
    KaliClub clubSig;
    KaliClubFactory factory;

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
        clubSig = new KaliClub(KaliClubSig(alice));
        // create the factory
        factory = new KaliClubFactory(clubSig);
    }

    function testDeployClubSig() public {
        KaliClub depClubSig;
        // create the Club[]
        IMember.Member[] memory members = new IMember.Member[](2);
        members[0] = IMember.Member(false, alice, 0);
        members[1] = IMember.Member(false, bob, 1);
        // vm.expectEmit(true, true, false, false);
        depClubSig = factory.deployClub(
            calls,
            members,
            2,
            name,
            symbol,
            false,
            'BASE'
        );
    }

    function testCloneAddressDetermination() public {
        KaliClub depClubSig;
        // create the Club[]
        IMember.Member[] memory members = new IMember.Member[](2);
        members[0] = IMember.Member(false, alice, 0);
        members[1] = IMember.Member(false, bob, 1);
        // vm.expectEmit(true, true, false, false);
        depClubSig = factory.deployClub(
            calls,
            members,
            2,
            name,
            symbol,
            false,
            'BASE'
        );
        // check CREATE2 clones match expected outputs
        (address clubAddr, bool deployed) = factory.determineClone(name, symbol);
        assertEq(
            address(depClubSig),
            clubAddr
        );
        assertEq(
            deployed,
            true
        );
        (, bool deployed2) = factory.determineClone(name2, symbol2);
        assertEq(
            deployed2,
            false
        );
    }
}
