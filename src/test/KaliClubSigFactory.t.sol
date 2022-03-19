pragma solidity >=0.8.4;

import {IClub} from "../interfaces/IClub.sol";

import {KaliClubSig} from "../KaliClubSig.sol";
import {ClubLoot} from "../ClubLoot.sol";
import {KaliClubSigFactory} from "../KaliClubSigFactory.sol";

import {DSTestPlus} from "./utils/DSTestPlus.sol";

import {stdError} from "@std/stdlib.sol";

contract KaliClubSigFactoryTest is DSTestPlus {
    KaliClubSig clubSig;
    ClubLoot loot;
    KaliClubSigFactory factory;

    /// @dev Users
    address public immutable alice = address(0xa);
    address public immutable bob = address(0xb);

    /// @notice Set up the testing suite
    function setUp() public {
        clubSig = new KaliClubSig();

        loot = new ClubLoot();

        // Create the factory
        factory = new KaliClubSigFactory(clubSig, loot);
    }

    function testDeployClubSig() public {
        KaliClubSig depClubSig;

        // Create the Club[]
        IClub.Club[] memory clubs = new IClub.Club[](2);
        clubs[0] = IClub.Club(alice, 0, 100);
        clubs[1] = IClub.Club(bob, 1, 100);

        vm_std_cheats.expectEmit(true, true, true, true);
        (depClubSig, ) = factory.deployClubSig(
            clubs,
            2,
            0,
            0x5445535400000000000000000000000000000000000000000000000000000000,
            0x5445535400000000000000000000000000000000000000000000000000000000,
            false,
            false,
            "BASE",
            "DOCS"
        );

        // Sanity check initialization
        assertEq(
            keccak256(bytes(depClubSig.baseURI())),
            keccak256(bytes("BASE"))
        );
    }
}
