// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {IClub} from '../interfaces/IClub.sol';
import {ClubSig} from '../ClubSig.sol';
import {LootERC20} from '../LootERC20.sol';
import {ClubSigFactory} from '../ClubSigFactory.sol';
import {DSTestPlus} from './utils/DSTestPlus.sol';

import {stdError} from '@std/stdlib.sol';

contract ClubSigTest is DSTestPlus {
    ClubSig clubSig;
    LootERC20 loot;
    ClubSigFactory factory;
    
    /// @dev Users
    address public alice = address(0xa);
    address public bob = address(0xb);
    address public charlie = address(0xc);
  
    /// @notice Set up the testing suite
    function setUp() public {
      clubSig = new ClubSig();
      loot = new LootERC20();
      
      // Create the factory
      factory = new ClubSigFactory(clubSig, loot);
      
      // Create the Club[]
      IClub.Club[] memory clubs = new IClub.Club[](2);
      clubs[0] = IClub.Club(alice, 0, 100);
      clubs[1] = IClub.Club(bob, 1, 100);
      
      (clubSig, ) = ClubSigFactory.deployClubSig(
        clubs,
        2,
        0x5445535400000000000000000000000000000000000000000000000000000000,
        0x5445535400000000000000000000000000000000000000000000000000000000,
        false,
        false,
        'DOCS',
        'BASE'
      );

      // Initialize
      //clubSig.init(
      //  alice,
      //  clubs,
      //  2,
      //  false,
      //  'DOCS',
      //  'BASE'
      //);

      // Sanity check initialization
      assertEq(keccak256(bytes(clubSig.baseURI())), keccak256(bytes('BASE')));
    }

    /// -----------------------------------------------------------------------
    /// Operations
    /// -----------------------------------------------------------------------

    function testGovernAlreadyMinted() public {
      IClub.Club[] memory clubs = new IClub.Club[](1);
      clubs[0] = IClub.Club(alice, 0, 100);

      bool[] memory mints = new bool[](1);
      mints[0] = true;

      vm.expectRevert(bytes4(keccak256('AlreadyMinted()')));
      vm.prank(address(clubSig));
      clubSig.govern(clubs, mints, 3);
    }

    function testGovernMint() public {
      address db = address(0xdeadbeef);

      IClub.Club[] memory clubs = new IClub.Club[](1);
      clubs[0] = IClub.Club(db, 2, 100);

      bool[] memory mints = new bool[](1);
      mints[0] = true;

      vm.prank(address(clubSig));
      clubSig.govern(clubs, mints, 3);
    }

    function testGovernBurn() public {
      IClub.Club[] memory clubs = new IClub.Club[](1);
      clubs[0] = IClub.Club(alice, 1, 100);

      bool[] memory mints = new bool[](1);
      mints[0] = false;

      vm.prank(address(clubSig));
      clubSig.govern(clubs, mints, 1);
    }

    function testFlipGovernor(address dave) public {
      startHoax(dave, dave, type(uint256).max);
      vm.expectRevert(bytes4(keccak256('Forbidden()')));
      clubSig.flipGovernor(dave);
      vm.stopPrank();

      // The ClubSig itself should be able to flip governor
      startHoax(address(clubSig), address(clubSig), type(uint256).max);
      clubSig.flipGovernor(dave);
      vm.stopPrank();
      assertTrue(clubSig.governor(dave));
    }

    function testFlipPause(address dave) public {
      startHoax(dave, dave, type(uint256).max);
      vm.expectRevert(bytes4(keccak256('Forbidden()')));
      clubSig.flipSignerPause();
      vm.stopPrank();
      assertTrue(!clubSig.paused());

      // The ClubSig itself should be able to flip pause
      startHoax(address(clubSig), address(clubSig), type(uint256).max);
      clubSig.flipSignerPause();
      vm.stopPrank();
      assertTrue(clubSig.paused());
    }

    function testUpdateURI(address dave) public {
      startHoax(dave, dave, type(uint256).max);
      vm.expectRevert(bytes4(keccak256('Forbidden()')));
      clubSig.updateURI('new_base_uri');
      vm.stopPrank();

      // The ClubSig itself should be able to update the base uri
      startHoax(address(clubSig), address(clubSig), type(uint256).max);
      clubSig.updateURI('new_base_uri');
      vm.stopPrank();
      assertEq(keccak256(bytes('new_base_uri')), keccak256(bytes(clubSig.baseURI())));
    }

    /// -----------------------------------------------------------------------
    /// Asset Management
    /// -----------------------------------------------------------------------

    //function testRageQuit(address a, address b) public {
    //  address[] memory assets = new address[](2);
    //  assets[0] = a > b ? b : a;
    //  assets[1] = a > b ? a : b;

    //  // Should revert on asset order
    //  vm.expectRevert(bytes4(keccak256('AssetOrder()')));
    //  clubSig.ragequit(assets, 100);

    //  // Switch the asset order
    //  assets[0] = a > b ? a : b;
    //  assets[1] = a > b ? b : a;

    //  // Should arithmetic underflow since not enough loot
    //  startHoax(charlie, charlie, type(uint256).max);
    //  vm.expectRevert(stdError.arithmeticError);
    //  clubSig.ragequit(assets, 100);
    //  vm.stopPrank();
    //}
}
