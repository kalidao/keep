// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {Call, KaliClub} from "../KaliClub.sol";
import {KaliClubFactory} from "../KaliClubFactory.sol";

import "@std/Test.sol";

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
    
    bytes32 name2 =
        0x5445535432000000000000000000000000000000000000000000000000000000;

    /// @notice Set up the testing suite

    function setUp() public {
        // create the templates
        clubSig = new KaliClub(KaliClub(alice));
        // create the factory
        factory = new KaliClubFactory(clubSig);
    }

    function testDeployClubSig() public {
        KaliClub depClubSig;
        // Create the Signer[]
        address[] memory signers = new address[](2);
        signers[0] = alice > bob
            ? bob
            : alice;
        signers[1] = alice > bob
            ? alice
            : bob;
        // vm.expectEmit(true, true, false, false);
        (depClubSig, ) = determineClone(name); 

        factory.deployClub(
            calls,
            signers,
            2,
            name
        );
    }

    function testCloneAddressDetermination() public {
        KaliClub depClubSig;
        // Create the Signer[]
        address[] memory signers = new address[](2);
        signers[0] = alice > bob
            ? bob
            : alice;
        signers[1] = alice > bob
            ? alice
            : bob;
        // vm.expectEmit(true, true, false, false);
        (depClubSig, ) = determineClone(name); 

        factory.deployClub(
            calls,
            signers,
            2,
            name
        );
        // check CREATE2 clones match expected outputs
        (address clubAddr, bool deployed) = factory.determineClone(name);
        assertEq(
            address(depClubSig),
            clubAddr
        );
        assertEq(
            deployed,
            true
        );
        (, bool deployed2) = factory.determineClone(name2);
        assertEq(
            deployed2,
            false
        );
    }
}
