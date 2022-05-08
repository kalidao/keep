pragma solidity >=0.8.4;

import {IClub} from '../interfaces/IClub.sol';
import {IRicardianLLC} from '../interfaces/IRicardianLLC.sol';

import {ClubLoot} from '../ClubLoot.sol';
import {KaliClubSig} from '../KaliClubSig.sol';
import {KaliClubSigFactory} from '../KaliClubSigFactory.sol';

import '@std/Test.sol';

contract KaliClubSigFactoryTest is Test {
    ClubLoot loot;
    KaliClubSig clubSig;
    KaliClubSigFactory factory;

    /// @dev Users

    address public immutable alice = address(0xa);
    address public immutable bob = address(0xb);

    /// @dev Integrations

    IRicardianLLC public immutable ricardian =
        IRicardianLLC(0x2017d429Ad722e1cf8df9F1A2504D4711cDedC49);

    /// @dev Helpers

    bytes32 name =
        0x5445535400000000000000000000000000000000000000000000000000000000;
    bytes32 symbol =
        0x5445535400000000000000000000000000000000000000000000000000000000;

    /// @notice Set up the testing suite

    function setUp() public {
        loot = new ClubLoot();
        clubSig = new KaliClubSig();
        // create the factory
        factory = new KaliClubSigFactory(loot, clubSig, ricardian);
    }

    function testDeployClubSig() public {
        KaliClubSig depClubSig;
        // create the Club[]
        IClub.Club[] memory clubs = new IClub.Club[](2);
        clubs[0] = IClub.Club(alice, 0, 100);
        clubs[1] = IClub.Club(bob, 1, 100);
        // vm.expectEmit(true, true, false, false);
        (, depClubSig) = factory.deployClubSig(
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

    function testCloneAddressComputation() public {
        ClubLoot depLoot;
        KaliClubSig depClubSig;
        // create the Club[]
        IClub.Club[] memory clubs = new IClub.Club[](2);
        clubs[0] = IClub.Club(alice, 0, 100);
        clubs[1] = IClub.Club(bob, 1, 100);
        // vm.expectEmit(true, true, false, false);
        (depLoot, depClubSig) = factory.deployClubSig(
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
        // check CREATE2 clones match expected outputs
        (address lootAddr, ) = factory.computeClones(name, symbol);
        assertEq(
            address(depLoot),
            lootAddr
        );
        //assertEq(
        //    address(depClubSig),
        //    clubAddr
        //);
    }
}
