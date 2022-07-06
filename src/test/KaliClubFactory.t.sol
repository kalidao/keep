// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {Call, KaliClub} from "../KaliClub.sol";
import {KaliClubFactory} from "../KaliClubFactory.sol";

import "@std/Test.sol";

contract KaliClubSigFactoryTest is Test {
    address clubAddr;
    KaliClub clubSig;
    KaliClubFactory factory;

    address[] signers;

    /// @dev Users

    address public immutable alice = address(0xa);
    address public immutable bob = address(0xb);

    /// @dev Helpers

    Call[] calls;

    bytes32 name =
        0x5445535400000000000000000000000000000000000000000000000000000000;
    
    bytes32 name2 =
        0x5445535432000000000000000000000000000000000000000000000000000000;

    /// @notice Set up the testing suite

    function setUp() public {
        // create the templates
        clubSig = new KaliClub(KaliClub(alice));
        // create the factory
        factory = new KaliClubFactory(clubSig);
        // Create the signers
        signers.push(alice);
        signers.push(bob);
    }

    function testDeployClubSig() public {
        factory.deployClub(
            calls,
            signers,
            2,
            name
        );
    }

    function testCloneAddressDetermination() public {
        (clubAddr, ) = factory.determineClub(name); 
        clubSig = KaliClub(clubAddr);
        factory.deployClub(
            calls,
            signers,
            2,
            name
        );
        // check CREATE2 clones match expected outputs
        bool deployed;
        (clubAddr, deployed) = factory.determineClub(name);
        assertEq(
            address(clubSig),
            clubAddr
        );
        assertEq(
            deployed,
            true
        );
        (, bool deployed2) = factory.determineClub(name2);
        assertEq(
            deployed2,
            false
        );
    }
}
