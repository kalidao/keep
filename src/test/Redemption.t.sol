// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {
    Operation, 
    Call, 
    Signature, 
    Keep
} from "../Keep.sol";
import {Redemption} from "../extensions/redemption/Redemption.sol";
import {KeepFactory} from "../KeepFactory.sol";

import {MockERC20} from "@solbase/test/utils/mocks/MockERC20.sol";

import "@std/Test.sol";

contract RedemptionTest is Test {
    using stdStorage for StdStorage;

    address clubAddr;
    Keep club;
    KeepFactory factory;
    MockERC20 mockDai;
    MockERC20 mockWeth;
    Redemption redemption;

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

    function writeTokenBalance(
        address who,
        address token,
        uint256 amt
    ) internal {
        stdstore
            .target(token)
            .sig(MockERC20(token).balanceOf.selector)
            .with_key(who)
            .checked_write(amt);
    }

    /// -----------------------------------------------------------------------
    /// Club Setup Tests
    /// -----------------------------------------------------------------------

    /// @notice Set up the testing suite

    function setUp() public {
        club = new Keep(Keep(alice));
        mockDai = new MockERC20("Dai", "DAI", 18);
        mockWeth = new MockERC20("wETH", "WETH", 18);
        redemption = new Redemption();

        // 1B mockDai!
        mockDai.mint(address(this), 1000000000 * 1e18);

        // 1B mockWeth!
        mockWeth.mint(address(this), 1000000000 * 1e18);

        // Create the factory
        factory = new KeepFactory(club);

        // Create the Signer[]
        address[] memory signers = new address[](2);
        signers[0] = alice > bob ? bob : alice;
        signers[1] = alice > bob ? alice : bob;

        clubAddr = factory.determineKeep(name);
        club = Keep(clubAddr);

        // The factory is fully tested in KeepFactory.t.sol
        factory.deployKeep(calls, signers, 2, name);
    }

    function testRedemption() public {
        startHoax(address(club), address(club), type(uint256).max);
        club.mint(
            address(redemption),
            uint256(bytes32(club.burn.selector)),
            1,
            ""
        );
        club.mint(alice, 1, 100, "");
        vm.stopPrank();

        assertTrue(club.balanceOf(alice, 1) == 100);

        mockDai.transfer(address(club), 100);

        startHoax(address(club), address(club), type(uint256).max);
        mockDai.approve(address(redemption), 100);
        redemption.setRedemptionStart(1, 100);
        vm.stopPrank();

        vm.warp(1641070800);

        address[] memory assets = new address[](1);
        assets[0] = address(mockDai);

        startHoax(alice, alice, type(uint256).max);
        redemption.redeem(address(club), assets, 1, 100);
        vm.stopPrank();

        assertTrue(club.balanceOf(alice, 1) == 0);
        assertTrue(club.totalSupply(1) == 0);
        assertTrue(mockDai.balanceOf(alice) == 100);
    }

    function testMultiRedemption() public {
        startHoax(address(club), address(club), type(uint256).max);
        club.mint(
            address(redemption),
            uint256(bytes32(club.burn.selector)),
            1,
            ""
        );
        club.mint(alice, 1, 100, "");
        vm.stopPrank();

        assertTrue(club.balanceOf(alice, 1) == 100);

        mockDai.transfer(address(club), 1000);
        mockWeth.transfer(address(club), 10);

        startHoax(address(club), address(club), type(uint256).max);
        mockDai.approve(address(redemption), 1000);
        mockWeth.approve(address(redemption), 10);
        redemption.setRedemptionStart(1, 100);
        vm.stopPrank();

        vm.warp(1641070800);

        address[] memory assets = new address[](2);
        assets[0] = address(mockDai);
        assets[1] = address(mockWeth);

        startHoax(address(alice), address(alice), type(uint256).max);
        redemption.redeem(address(club), assets, 1, 50);
        vm.stopPrank();

        assertTrue(club.balanceOf(alice, 1) == 50);
        assertTrue(club.totalSupply(1) == 50);
        assertTrue(mockDai.balanceOf(alice) == 500);
        assertTrue(mockWeth.balanceOf(alice) == 5);

        startHoax(address(alice), address(alice), type(uint256).max);
        redemption.redeem(address(club), assets, 1, 50);
        vm.stopPrank();

        assertTrue(club.balanceOf(alice, 1) == 0);
        assertTrue(club.totalSupply(1) == 0);
        assertTrue(mockDai.balanceOf(alice) == 1000);
        assertTrue(mockWeth.balanceOf(alice) == 10);
    }
}
