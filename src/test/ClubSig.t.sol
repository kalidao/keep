// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {ClubSig} from "../ClubSig.sol";
import {DSTestPlus} from "./utils/DSTestPlus.sol";

contract ClubSigTest is DSTestPlus {
    ClubSig clubSig;

    /// @dev Users
    address public alice = address(0xa);
    address public bob = address(0xb);

    /// @notice Set up the testing suite
    function setUp() public {
      clubSig = new ClubSig();

      // Create the Club[]
      ClubSig.Club[] memory clubs = new ClubSig.Club[](2);
      clubs[0] = ClubSig.Club(alice, 0, 100);
      clubs[1] = ClubSig.Club(bob, 1, 100);

      // Initialize
      clubSig.init(
        clubs,
        2,
        false,
        "BASE"
      );

      // Sanity check initialization
      assertEq(keccak256(bytes(clubSig.baseURI())), keccak256(bytes("BASE")));
    }

    /// -----------------------------------------------------------------------
    /// Operations
    /// -----------------------------------------------------------------------

    function testFlipGovernor(address charlie) public {
      vm.expectRevert(bytes4(keccak256("Forbidden()")));
      clubSig.flipGovernor(charlie);
    }

    function testGovernAlreadyMinted() public {
      ClubSig.Club[] memory clubs = new ClubSig.Club[](1);
      clubs[0] = ClubSig.Club(alice, 0, 100);

      bool[] memory mints = new bool[](1);
      mints[0] = true;

      vm.expectRevert(bytes4(keccak256("AlreadyMinted()")));
      vm.prank(address(clubSig));
      clubSig.govern(clubs, mints, 3);
    }

    function testGovernMint() public {
      address db = address(0xdeadbeef);

      ClubSig.Club[] memory clubs = new ClubSig.Club[](1);
      clubs[0] = ClubSig.Club(db, 2, 100);

      bool[] memory mints = new bool[](1);
      mints[0] = true;

      vm.prank(address(clubSig));
      clubSig.govern(clubs, mints, 3);
    }

    function testGovernBurn() public {
      ClubSig.Club[] memory clubs = new ClubSig.Club[](1);
      clubs[0] = ClubSig.Club(alice, 1, 100);

      bool[] memory mints = new bool[](1);
      mints[0] = false;

      vm.prank(address(clubSig));
      clubSig.govern(clubs, mints, 1);
    }
}