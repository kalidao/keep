// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Standard, RageRouter} from "@kali/RageRouter.sol";

import {MockERC20} from "@solbase/test/utils/mocks/MockERC20.sol";
import {MockERC721Supply} from "@solbase/test/utils/mocks/MockERC721Supply.sol";
import {MockERC1155Supply} from "@solbase/test/utils/mocks/MockERC1155Supply.sol";
import {MockERC1271Wallet} from "@solbase/test/utils/mocks/MockERC1271Wallet.sol";

import "@std/Test.sol";

contract RageRouterTest is Test {
    using stdStorage for StdStorage;

    RageRouter router;

    MockERC20 mockGovERC20;
    MockERC721Supply mockGovERC721;
    MockERC1155Supply mockGovERC1155;

    MockERC20 mockDai;
    MockERC20 mockWeth;

    Standard internal constant erc20std = Standard.ERC20;
    Standard internal constant erc721std = Standard.ERC721;
    Standard internal constant erc1155std = Standard.ERC1155;

    address internal immutable alice = vm.addr(1);
    address internal immutable bob = vm.addr(2);
    address internal burner;
    address internal immutable treasury = address(this);

    uint256 internal start;

    /// -----------------------------------------------------------------------
    /// Setup
    /// -----------------------------------------------------------------------

    function setUp() public {
        router = new RageRouter();

        mockGovERC20 = new MockERC20("Gov", "GOV", 18);
        mockGovERC721 = new MockERC721Supply("Gov", "GOV");
        mockGovERC1155 = new MockERC1155Supply();

        burner = address(new MockERC1271Wallet(alice));

        mockDai = new MockERC20("Dai", "DAI", 18);
        mockWeth = new MockERC20("wETH", "WETH", 18);

        // 50 mockGovERC20.
        mockGovERC20.mint(alice, 50 ether);
        // 50 mockGovERC20.
        mockGovERC20.mint(bob, 50 ether);

        // 1 mockGovERC721.
        mockGovERC721.mint(alice, 0);
        // 1 mockGovERC721.
        mockGovERC721.mint(bob, 1);

        // 50 mockGovERC1155.
        mockGovERC1155.mint(alice, 0, 50 ether, "");
        // 50 mockGovERC1155.
        mockGovERC1155.mint(bob, 0, 50 ether, "");

        // 1000 mockDai.
        mockDai.mint(address(this), 1000 ether);
        // 10 mockWeth.
        mockWeth.mint(address(this), 10 ether);

        // ERC20 approvals.
        mockGovERC20.approve(address(router), 100 ether);
        mockDai.approve(address(router), 1000 ether);
        mockWeth.approve(address(router), 10 ether);

        // Alice gov approvals.
        startHoax(alice, alice, type(uint256).max);
        // More than enough for arithmetic test cases.
        mockGovERC20.approve(address(router), 100_0000 ether);
        mockGovERC721.setApprovalForAll(address(router), true);
        mockGovERC1155.setApprovalForAll(address(router), true);
        vm.stopPrank();

        // Bob gov approvals.
        startHoax(bob, bob, type(uint256).max);
        // More than enough for arithmetic test cases.
        mockGovERC20.approve(address(router), 100_0000 ether);
        mockGovERC721.setApprovalForAll(address(router), true);
        mockGovERC1155.setApprovalForAll(address(router), true);
        vm.stopPrank();

        // Treasury asset approvals.
        mockDai.approve(address(router), 1000 ether);
        mockWeth.approve(address(router), 10 ether);

        // Set redemption start.
        start = 1000;
    }

    /// -----------------------------------------------------------------------
    /// Test Logic
    /// -----------------------------------------------------------------------

    function testDeploy() public payable {
        new RageRouter();
    }

    /// -----------------------------------------------------------------------
    /// Burnable Tokens
    /// -----------------------------------------------------------------------

    function testRedeemERC20() public payable {
        router.setRagequit(
            address(0),
            address(mockGovERC20),
            Standard.ERC20,
            0,
            start
        );
        vm.warp(1641070800);

        // Check initial gov balances.
        assertTrue(mockGovERC20.balanceOf(alice) == 50 ether);
        assertTrue(mockGovERC20.totalSupply() == 100 ether);

        // Check initial unredeemed wETH.
        assertTrue(mockWeth.balanceOf(alice) == 0 ether);
        assertTrue(mockWeth.balanceOf(treasury) == 10 ether);

        // Set up wETH claim.
        address[] memory singleAsset = new address[](1);
        singleAsset[0] = address(mockWeth);

        // Mock alice to redeem gov for wETH.
        startHoax(alice, alice, type(uint256).max);
        router.ragequit(treasury, singleAsset, 25 ether);
        vm.stopPrank();

        // Check resulting gov balances.
        assertTrue(mockGovERC20.balanceOf(alice) == 25 ether);
        assertTrue(mockGovERC20.totalSupply() == 75 ether);

        // Check resulting redeemed wETH.
        assertTrue(mockWeth.balanceOf(alice) == 2.5 ether);
        assertTrue(mockWeth.balanceOf(treasury) == 7.5 ether);
    }

    function testRedeemMultiERC20() public payable {
        router.setRagequit(
            address(0),
            address(mockGovERC20),
            Standard.ERC20,
            0,
            start
        );
        vm.warp(1641070800);

        // Check initial gov balances.
        assertTrue(mockGovERC20.balanceOf(alice) == 50 ether);
        assertTrue(mockGovERC20.totalSupply() == 100 ether);

        // Check initial unredeemed wETH.
        assertTrue(mockWeth.balanceOf(alice) == 0 ether);
        assertTrue(mockWeth.balanceOf(treasury) == 10 ether);

        // Check initial unredeemed Dai.
        assertTrue(mockDai.balanceOf(alice) == 0 ether);
        assertTrue(mockDai.balanceOf(treasury) == 1000 ether);

        // Set up wETH/Dai claim.
        address[] memory multiAsset = new address[](2);
        multiAsset[1] = address(mockWeth);
        multiAsset[0] = address(mockDai);

        // Mock alice to redeem gov for wETH/Dai.
        startHoax(alice, alice, type(uint256).max);
        router.ragequit(treasury, multiAsset, 25 ether);
        vm.stopPrank();

        // Check resulting gov balances.
        assertTrue(mockGovERC20.balanceOf(alice) == 25 ether);
        assertTrue(mockGovERC20.totalSupply() == 75 ether);

        // Check resulting redeemed wETH.
        assertTrue(mockWeth.balanceOf(alice) == 2.5 ether);
        assertTrue(mockWeth.balanceOf(treasury) == 7.5 ether);

        // Check resulting redeemed Dai.
        assertTrue(mockDai.balanceOf(alice) == 250 ether);
        assertTrue(mockDai.balanceOf(treasury) == 750 ether);
    }

    function testRedeemERC721() public payable {
        router.setRagequit(
            address(0),
            address(mockGovERC721),
            Standard.ERC721,
            0,
            start
        );
        vm.warp(1641070800);

        // Check initial gov balances.
        assertTrue(mockGovERC721.ownerOf(0) == alice);
        assertTrue(mockGovERC721.balanceOf(alice) == 1);
        assertTrue(mockGovERC721.totalSupply() == 2);

        // Check initial unredeemed wETH.
        assertTrue(mockWeth.balanceOf(alice) == 0 ether);
        assertTrue(mockWeth.balanceOf(treasury) == 10 ether);

        // Set up wETH claim.
        address[] memory singleAsset = new address[](1);
        singleAsset[0] = address(mockWeth);

        // Mock alice to redeem gov for wETH.
        startHoax(alice, alice, type(uint256).max);
        router.ragequit(treasury, singleAsset, 0);
        vm.stopPrank();

        // Check resulting gov balances.
        assertTrue(mockGovERC721.balanceOf(alice) == 0);
        assertTrue(mockGovERC721.totalSupply() == 1);

        // Check resulting redeemed wETH.
        assertTrue(mockWeth.balanceOf(alice) == 5 ether);
        assertTrue(mockWeth.balanceOf(treasury) == 5 ether);
    }

    function testRedeemMultiERC721() public payable {
        router.setRagequit(
            address(0),
            address(mockGovERC721),
            Standard.ERC721,
            0,
            start
        );
        vm.warp(1641070800);

        // Check initial gov balances.
        assertTrue(mockGovERC721.ownerOf(0) == alice);
        assertTrue(mockGovERC721.balanceOf(alice) == 1);
        assertTrue(mockGovERC721.totalSupply() == 2);

        // Check initial unredeemed wETH.
        assertTrue(mockWeth.balanceOf(alice) == 0 ether);
        assertTrue(mockWeth.balanceOf(treasury) == 10 ether);

        // Check initial unredeemed Dai.
        assertTrue(mockDai.balanceOf(alice) == 0 ether);
        assertTrue(mockDai.balanceOf(treasury) == 1000 ether);

        // Set up wETH/Dai claim.
        address[] memory multiAsset = new address[](2);
        multiAsset[1] = address(mockWeth);
        multiAsset[0] = address(mockDai);

        // Mock alice to redeem gov for wETH/Dai.
        startHoax(alice, alice, type(uint256).max);
        router.ragequit(treasury, multiAsset, 0);
        vm.stopPrank();

        // Check resulting gov balances.
        assertTrue(mockGovERC721.balanceOf(alice) == 0);
        assertTrue(mockGovERC721.totalSupply() == 1);

        // Check resulting redeemed wETH.
        assertTrue(mockWeth.balanceOf(alice) == 5 ether);
        assertTrue(mockWeth.balanceOf(treasury) == 5 ether);

        // Check resulting redeemed Dai.
        assertTrue(mockDai.balanceOf(alice) == 500 ether);
        assertTrue(mockDai.balanceOf(treasury) == 500 ether);
    }

    function testRedeemERC1155() public payable {
        router.setRagequit(
            address(0),
            address(mockGovERC1155),
            Standard.ERC1155,
            0,
            start
        );
        vm.warp(1641070800);

        // Check initial gov balances.
        assertTrue(mockGovERC1155.balanceOf(alice, 0) == 50 ether);
        assertTrue(mockGovERC1155.totalSupply(0) == 100 ether);

        // Check initial unredeemed wETH.
        assertTrue(mockWeth.balanceOf(alice) == 0 ether);
        assertTrue(mockWeth.balanceOf(treasury) == 10 ether);

        // Set up wETH claim.
        address[] memory singleAsset = new address[](1);
        singleAsset[0] = address(mockWeth);

        // Mock alice to redeem gov for wETH.
        startHoax(alice, alice, type(uint256).max);
        router.ragequit(treasury, singleAsset, 25 ether);
        vm.stopPrank();

        // Check resulting gov balances.
        assertTrue(mockGovERC1155.balanceOf(alice, 0) == 25 ether);
        assertTrue(mockGovERC1155.totalSupply(0) == 75 ether);

        // Check resulting redeemed wETH.
        assertTrue(mockWeth.balanceOf(alice) == 2.5 ether);
        assertTrue(mockWeth.balanceOf(treasury) == 7.5 ether);
    }

    function testRedeemMultiERC1155() public payable {
        router.setRagequit(
            address(0),
            address(mockGovERC1155),
            Standard.ERC1155,
            0,
            start
        );
        vm.warp(1641070800);

        // Check initial gov balances.
        assertTrue(mockGovERC1155.balanceOf(alice, 0) == 50 ether);
        assertTrue(mockGovERC1155.totalSupply(0) == 100 ether);

        // Check initial unredeemed wETH.
        assertTrue(mockWeth.balanceOf(alice) == 0 ether);
        assertTrue(mockWeth.balanceOf(treasury) == 10 ether);

        // Check initial unredeemed Dai.
        assertTrue(mockDai.balanceOf(alice) == 0 ether);
        assertTrue(mockDai.balanceOf(treasury) == 1000 ether);

        // Set up wETH/Dai claim.
        address[] memory multiAsset = new address[](2);
        multiAsset[1] = address(mockWeth);
        multiAsset[0] = address(mockDai);

        // Mock alice to redeem gov for wETH/Dai.
        startHoax(alice, alice, type(uint256).max);
        router.ragequit(treasury, multiAsset, 25 ether);
        vm.stopPrank();

        // Check resulting gov balances.
        assertTrue(mockGovERC1155.balanceOf(alice, 0) == 25 ether);
        assertTrue(mockGovERC1155.totalSupply(0) == 75 ether);

        // Check resulting redeemed wETH.
        assertTrue(mockWeth.balanceOf(alice) == 2.5 ether);
        assertTrue(mockWeth.balanceOf(treasury) == 7.5 ether);

        // Check resulting redeemed Dai.
        assertTrue(mockDai.balanceOf(alice) == 250 ether);
        assertTrue(mockDai.balanceOf(treasury) == 750 ether);
    }

    function testGradualRedemption() public payable {
        router.setRagequit(
            address(0),
            address(mockGovERC20),
            Standard.ERC20,
            0,
            start
        );
        vm.warp(1641070800);

        // Check initial gov balances.
        assertTrue(mockGovERC20.balanceOf(alice) == 50 ether);
        assertTrue(mockGovERC20.balanceOf(bob) == 50 ether);
        assertTrue(mockGovERC20.totalSupply() == 100 ether);

        // Check initial unredeemed wETH.
        assertTrue(mockWeth.balanceOf(alice) == 0 ether);
        assertTrue(mockWeth.balanceOf(bob) == 0 ether);
        assertTrue(mockWeth.balanceOf(treasury) == 10 ether);

        // Set up wETH claim.
        address[] memory singleAsset = new address[](1);
        singleAsset[0] = address(mockWeth);

        // Mock alice to redeem gov for wETH.
        startHoax(alice, alice, type(uint256).max);
        router.ragequit(treasury, singleAsset, 25 ether);
        vm.stopPrank();

        // Check resulting gov balances.
        assertTrue(mockGovERC20.balanceOf(alice) == 25 ether);
        assertTrue(mockGovERC20.totalSupply() == 75 ether);

        // Check resulting redeemed wETH.
        assertTrue(mockWeth.balanceOf(alice) == 2.5 ether);
        assertTrue(mockWeth.balanceOf(treasury) == 7.5 ether);

        // Mock bob to redeem gov for wETH.
        startHoax(bob, bob, type(uint256).max);
        router.ragequit(treasury, singleAsset, 25 ether);
        vm.stopPrank();

        // Check resulting gov balances.
        assertTrue(mockGovERC20.balanceOf(bob) == 25 ether);
        assertTrue(mockGovERC20.totalSupply() == 50 ether);

        // Check resulting redeemed wETH.
        assertTrue(mockWeth.balanceOf(bob) == 2.5 ether);
        assertTrue(mockWeth.balanceOf(treasury) == 5 ether);

        // Mock alice to redeem gov for wETH.
        startHoax(alice, alice, type(uint256).max);
        router.ragequit(treasury, singleAsset, 25 ether);
        vm.stopPrank();

        // Check resulting gov balances.
        assertTrue(mockGovERC20.balanceOf(alice) == 0 ether);
        assertTrue(mockGovERC20.totalSupply() == 25 ether);

        // Check resulting redeemed wETH.
        assertTrue(mockWeth.balanceOf(alice) == 5 ether);
        assertTrue(mockWeth.balanceOf(treasury) == 2.5 ether);

        // Expect revert in underflow for Alice repeat.
        startHoax(alice, alice, type(uint256).max);
        vm.expectRevert(stdError.arithmeticError);
        router.ragequit(treasury, singleAsset, 25 ether);
        vm.stopPrank();

        // Mock bob to redeem gov for wETH.
        // This completes redemption.
        startHoax(bob, bob, type(uint256).max);
        router.ragequit(treasury, singleAsset, 25 ether);
        vm.stopPrank();

        // Check resulting gov balances.
        assertTrue(mockGovERC20.balanceOf(bob) == 0 ether);
        assertTrue(mockGovERC20.totalSupply() == 0 ether);

        // Check resulting redeemed wETH.
        assertTrue(mockWeth.balanceOf(bob) == 5 ether);
        assertTrue(mockWeth.balanceOf(treasury) == 0 ether);
    }

    function testCompleteRedemption() public payable {
        router.setRagequit(
            address(0),
            address(mockGovERC20),
            Standard.ERC20,
            0,
            start
        );
        vm.warp(1641070800);

        // Check initial gov balances.
        assertTrue(mockGovERC20.balanceOf(alice) == 50 ether);
        assertTrue(mockGovERC20.balanceOf(bob) == 50 ether);
        assertTrue(mockGovERC20.totalSupply() == 100 ether);

        // Check initial unredeemed wETH.
        assertTrue(mockWeth.balanceOf(alice) == 0 ether);
        assertTrue(mockWeth.balanceOf(bob) == 0 ether);
        assertTrue(mockWeth.balanceOf(treasury) == 10 ether);

        // Set up wETH claim.
        address[] memory singleAsset = new address[](1);
        singleAsset[0] = address(mockWeth);

        // Mock alice to redeem gov for wETH.
        startHoax(alice, alice, type(uint256).max);
        router.ragequit(treasury, singleAsset, 50 ether);
        vm.stopPrank();

        // Check resulting gov balances.
        assertTrue(mockGovERC20.balanceOf(alice) == 0 ether);
        assertTrue(mockGovERC20.totalSupply() == 50 ether);

        // Check resulting redeemed wETH.
        assertTrue(mockWeth.balanceOf(alice) == 5 ether);
        assertTrue(mockWeth.balanceOf(treasury) == 5 ether);

        // Mock bob to redeem gov for wETH.
        // This completes redemption.
        startHoax(bob, bob, type(uint256).max);
        router.ragequit(treasury, singleAsset, 50 ether);
        vm.stopPrank();

        // Check resulting gov balances.
        assertTrue(mockGovERC20.balanceOf(bob) == 0 ether);
        assertTrue(mockGovERC20.totalSupply() == 0 ether);

        // Check resulting redeemed wETH.
        assertTrue(mockWeth.balanceOf(bob) == 5 ether);
        assertTrue(mockWeth.balanceOf(treasury) == 0 ether);
    }

    function testCannotRedeemEarly() public payable {
        router.setRagequit(
            address(0),
            address(mockGovERC20),
            Standard.ERC20,
            0,
            start
        );
        vm.warp(1641070800);

        // Check initial gov balances.
        assertTrue(mockGovERC20.balanceOf(alice) == 50 ether);
        assertTrue(mockGovERC20.balanceOf(bob) == 50 ether);
        assertTrue(mockGovERC20.totalSupply() == 100 ether);

        // Check initial unredeemed wETH.
        assertTrue(mockWeth.balanceOf(alice) == 0 ether);
        assertTrue(mockWeth.balanceOf(bob) == 0 ether);
        assertTrue(mockWeth.balanceOf(treasury) == 10 ether);

        // Set up wETH claim.
        address[] memory singleAsset = new address[](1);
        singleAsset[0] = address(mockWeth);

        // Mock alice to redeem gov for wETH too early.
        vm.warp(start - 1);
        vm.expectRevert(bytes4(keccak256("NotStarted()")));
        startHoax(alice, alice, type(uint256).max);
        router.ragequit(treasury, singleAsset, 50 ether);
        vm.stopPrank();

        // Check resulting gov balances.
        assertTrue(mockGovERC20.balanceOf(alice) == 50 ether);
        assertTrue(mockGovERC20.totalSupply() == 100 ether);

        // Check resulting redeemed wETH.
        assertTrue(mockWeth.balanceOf(alice) == 0 ether);
        assertTrue(mockWeth.balanceOf(treasury) == 10 ether);
    }

    function testCannotRedeemMultiAssetOutOfOrder() public payable {
        router.setRagequit(
            address(0),
            address(mockGovERC20),
            Standard.ERC20,
            0,
            start
        );
        vm.warp(1641070800);

        // Check initial gov balances.
        assertTrue(mockGovERC20.balanceOf(alice) == 50 ether);
        assertTrue(mockGovERC20.totalSupply() == 100 ether);

        // Check initial unredeemed wETH.
        assertTrue(mockWeth.balanceOf(alice) == 0 ether);
        assertTrue(mockWeth.balanceOf(treasury) == 10 ether);

        // Check initial unredeemed Dai.
        assertTrue(mockDai.balanceOf(alice) == 0 ether);
        assertTrue(mockDai.balanceOf(treasury) == 1000 ether);

        // Set up wETH/Dai claim.
        address[] memory multiAsset = new address[](2);
        multiAsset[1] = address(mockDai);
        multiAsset[0] = address(mockWeth);

        // Mock alice to redeem gov for wETH/Dai.
        startHoax(alice, alice, type(uint256).max);
        vm.expectRevert(bytes4(keccak256("InvalidAssetOrder()")));
        router.ragequit(treasury, multiAsset, 25 ether);
        vm.stopPrank();

        // Check resulting gov balances.
        assertTrue(mockGovERC20.balanceOf(alice) == 50 ether);
        assertTrue(mockGovERC20.totalSupply() == 100 ether);

        // Check resulting redeemed wETH.
        assertTrue(mockWeth.balanceOf(alice) == 0 ether);
        assertTrue(mockWeth.balanceOf(treasury) == 10 ether);

        // Check resulting redeemed Dai.
        assertTrue(mockDai.balanceOf(alice) == 0 ether);
        assertTrue(mockDai.balanceOf(treasury) == 1000 ether);
    }

    /// -----------------------------------------------------------------------
    /// Non-Burnable Tokens
    /// -----------------------------------------------------------------------

    function testRedeemERC20NonBurnable() public payable {
        router.setRagequit(
            burner,
            address(mockGovERC20),
            Standard.ERC20,
            0,
            start
        );
        vm.warp(1641070800);

        // Check initial gov balances.
        assertTrue(mockGovERC20.balanceOf(alice) == 50 ether);
        assertTrue(mockGovERC20.totalSupply() == 100 ether);

        // Check initial unredeemed wETH.
        assertTrue(mockWeth.balanceOf(alice) == 0 ether);
        assertTrue(mockWeth.balanceOf(treasury) == 10 ether);

        // Set up wETH claim.
        address[] memory singleAsset = new address[](1);
        singleAsset[0] = address(mockWeth);

        // Mock alice to redeem gov for wETH.
        startHoax(alice, alice, type(uint256).max);
        router.ragequit(treasury, singleAsset, 25 ether);
        vm.stopPrank();

        // Check resulting gov balances.
        assertTrue(mockGovERC20.balanceOf(alice) == 25 ether);
        assertTrue(
            mockGovERC20.totalSupply() ==
                75 ether + mockGovERC20.balanceOf(burner)
        );

        // Check resulting redeemed wETH.
        assertTrue(mockWeth.balanceOf(alice) == 2.5 ether);
        assertTrue(mockWeth.balanceOf(treasury) == 7.5 ether);
    }

    function testRedeemMultiERC20NonBurnable() public payable {
        router.setRagequit(
            burner,
            address(mockGovERC20),
            Standard.ERC20,
            0,
            start
        );
        vm.warp(1641070800);

        // Check initial gov balances.
        assertTrue(mockGovERC20.balanceOf(alice) == 50 ether);
        assertTrue(mockGovERC20.totalSupply() == 100 ether);

        // Check initial unredeemed wETH.
        assertTrue(mockWeth.balanceOf(alice) == 0 ether);
        assertTrue(mockWeth.balanceOf(treasury) == 10 ether);

        // Check initial unredeemed Dai.
        assertTrue(mockDai.balanceOf(alice) == 0 ether);
        assertTrue(mockDai.balanceOf(treasury) == 1000 ether);

        // Set up wETH/Dai claim.
        address[] memory multiAsset = new address[](2);
        multiAsset[1] = address(mockWeth);
        multiAsset[0] = address(mockDai);

        // Mock alice to redeem gov for wETH/Dai.
        startHoax(alice, alice, type(uint256).max);
        router.ragequit(treasury, multiAsset, 25 ether);
        vm.stopPrank();

        // Check resulting gov balances.
        assertTrue(mockGovERC20.balanceOf(alice) == 25 ether);
        assertTrue(
            mockGovERC20.totalSupply() ==
                75 ether + mockGovERC20.balanceOf(burner)
        );

        // Check resulting redeemed wETH.
        assertTrue(mockWeth.balanceOf(alice) == 2.5 ether);
        assertTrue(mockWeth.balanceOf(treasury) == 7.5 ether);

        // Check resulting redeemed Dai.
        assertTrue(mockDai.balanceOf(alice) == 250 ether);
        assertTrue(mockDai.balanceOf(treasury) == 750 ether);
    }

    function testRedeemERC721NonBurnable() public payable {
        router.setRagequit(
            burner,
            address(mockGovERC721),
            Standard.ERC721,
            0,
            start
        );
        vm.warp(1641070800);

        // Check initial gov balances.
        assertTrue(mockGovERC721.ownerOf(0) == alice);
        assertTrue(mockGovERC721.balanceOf(alice) == 1);
        assertTrue(mockGovERC721.totalSupply() == 2);

        // Check initial unredeemed wETH.
        assertTrue(mockWeth.balanceOf(alice) == 0 ether);
        assertTrue(mockWeth.balanceOf(treasury) == 10 ether);

        // Set up wETH claim.
        address[] memory singleAsset = new address[](1);
        singleAsset[0] = address(mockWeth);

        // Mock alice to redeem gov for wETH.
        startHoax(alice, alice, type(uint256).max);
        router.ragequit(treasury, singleAsset, 0);
        vm.stopPrank();

        // Check resulting gov balances.
        assertTrue(mockGovERC721.balanceOf(alice) == 0);
        assertTrue(
            mockGovERC721.totalSupply() == 1 + mockGovERC721.balanceOf(burner)
        );

        // Check resulting redeemed wETH.
        assertTrue(mockWeth.balanceOf(alice) == 5 ether);
        assertTrue(mockWeth.balanceOf(treasury) == 5 ether);
    }

    function testRedeemMultiERC721NonBurnable() public payable {
        router.setRagequit(
            burner,
            address(mockGovERC721),
            Standard.ERC721,
            0,
            start
        );
        vm.warp(1641070800);

        // Check initial gov balances.
        assertTrue(mockGovERC721.ownerOf(0) == alice);
        assertTrue(mockGovERC721.balanceOf(alice) == 1);
        assertTrue(mockGovERC721.totalSupply() == 2);

        // Check initial unredeemed wETH.
        assertTrue(mockWeth.balanceOf(alice) == 0 ether);
        assertTrue(mockWeth.balanceOf(treasury) == 10 ether);

        // Check initial unredeemed Dai.
        assertTrue(mockDai.balanceOf(alice) == 0 ether);
        assertTrue(mockDai.balanceOf(treasury) == 1000 ether);

        // Set up wETH/Dai claim.
        address[] memory multiAsset = new address[](2);
        multiAsset[1] = address(mockWeth);
        multiAsset[0] = address(mockDai);

        // Mock alice to redeem gov for wETH/Dai.
        startHoax(alice, alice, type(uint256).max);
        router.ragequit(treasury, multiAsset, 0);
        vm.stopPrank();

        // Check resulting gov balances.
        assertTrue(mockGovERC721.balanceOf(alice) == 0);
        assertTrue(
            mockGovERC721.totalSupply() == 1 + mockGovERC721.balanceOf(burner)
        );

        // Check resulting redeemed wETH.
        assertTrue(mockWeth.balanceOf(alice) == 5 ether);
        assertTrue(mockWeth.balanceOf(treasury) == 5 ether);

        // Check resulting redeemed Dai.
        assertTrue(mockDai.balanceOf(alice) == 500 ether);
        assertTrue(mockDai.balanceOf(treasury) == 500 ether);
    }

    function testRedeemERC1155NonBurnable() public payable {
        router.setRagequit(
            burner,
            address(mockGovERC1155),
            Standard.ERC1155,
            0,
            start
        );
        vm.warp(1641070800);

        // Check initial gov balances.
        assertTrue(mockGovERC1155.balanceOf(alice, 0) == 50 ether);
        assertTrue(mockGovERC1155.totalSupply(0) == 100 ether);

        // Check initial unredeemed wETH.
        assertTrue(mockWeth.balanceOf(alice) == 0 ether);
        assertTrue(mockWeth.balanceOf(treasury) == 10 ether);

        // Set up wETH claim.
        address[] memory singleAsset = new address[](1);
        singleAsset[0] = address(mockWeth);

        // Mock alice to redeem gov for wETH.
        startHoax(alice, alice, type(uint256).max);
        router.ragequit(treasury, singleAsset, 25 ether);
        vm.stopPrank();

        // Check resulting gov balances.
        assertTrue(mockGovERC1155.balanceOf(alice, 0) == 25 ether);
        assertTrue(
            mockGovERC1155.totalSupply(0) ==
                75 ether + mockGovERC1155.balanceOf(burner, 0)
        );

        // Check resulting redeemed wETH.
        assertTrue(mockWeth.balanceOf(alice) == 2.5 ether);
        assertTrue(mockWeth.balanceOf(treasury) == 7.5 ether);
    }

    function testRedeemMultiERC1155NonBurnable() public payable {
        router.setRagequit(
            burner,
            address(mockGovERC1155),
            Standard.ERC1155,
            0,
            start
        );
        vm.warp(1641070800);

        // Check initial gov balances.
        assertTrue(mockGovERC1155.balanceOf(alice, 0) == 50 ether);
        assertTrue(mockGovERC1155.totalSupply(0) == 100 ether);

        // Check initial unredeemed wETH.
        assertTrue(mockWeth.balanceOf(alice) == 0 ether);
        assertTrue(mockWeth.balanceOf(treasury) == 10 ether);

        // Check initial unredeemed Dai.
        assertTrue(mockDai.balanceOf(alice) == 0 ether);
        assertTrue(mockDai.balanceOf(treasury) == 1000 ether);

        // Set up wETH/Dai claim.
        address[] memory multiAsset = new address[](2);
        multiAsset[1] = address(mockWeth);
        multiAsset[0] = address(mockDai);

        // Mock alice to redeem gov for wETH/Dai.
        startHoax(alice, alice, type(uint256).max);
        router.ragequit(treasury, multiAsset, 25 ether);
        vm.stopPrank();

        // Check resulting gov balances.
        assertTrue(mockGovERC1155.balanceOf(alice, 0) == 25 ether);
        assertTrue(
            mockGovERC1155.totalSupply(0) ==
                75 ether + mockGovERC1155.balanceOf(burner, 0)
        );

        // Check resulting redeemed wETH.
        assertTrue(mockWeth.balanceOf(alice) == 2.5 ether);
        assertTrue(mockWeth.balanceOf(treasury) == 7.5 ether);

        // Check resulting redeemed Dai.
        assertTrue(mockDai.balanceOf(alice) == 250 ether);
        assertTrue(mockDai.balanceOf(treasury) == 750 ether);
    }

    function testGradualRedemptionNonBurnable() public payable {
        router.setRagequit(
            burner,
            address(mockGovERC20),
            Standard.ERC20,
            0,
            start
        );
        vm.warp(1641070800);

        // Check initial gov balances.
        assertTrue(mockGovERC20.balanceOf(alice) == 50 ether);
        assertTrue(mockGovERC20.balanceOf(bob) == 50 ether);
        assertTrue(mockGovERC20.totalSupply() == 100 ether);

        // Check initial unredeemed wETH.
        assertTrue(mockWeth.balanceOf(alice) == 0 ether);
        assertTrue(mockWeth.balanceOf(bob) == 0 ether);
        assertTrue(mockWeth.balanceOf(treasury) == 10 ether);

        // Set up wETH claim.
        address[] memory singleAsset = new address[](1);
        singleAsset[0] = address(mockWeth);

        // Mock alice to redeem gov for wETH.
        startHoax(alice, alice, type(uint256).max);
        router.ragequit(treasury, singleAsset, 25 ether);
        vm.stopPrank();

        // Check resulting gov balances.
        assertTrue(mockGovERC20.balanceOf(alice) == 25 ether);
        assertTrue(
            mockGovERC20.totalSupply() ==
                75 ether + mockGovERC20.balanceOf(burner)
        );

        // Check resulting redeemed wETH.
        assertTrue(mockWeth.balanceOf(alice) == 2.5 ether);
        assertTrue(mockWeth.balanceOf(treasury) == 7.5 ether);

        // Mock bob to redeem gov for wETH.
        startHoax(bob, bob, type(uint256).max);
        router.ragequit(treasury, singleAsset, 25 ether);
        vm.stopPrank();

        // Check resulting gov balances.
        assertTrue(mockGovERC20.balanceOf(bob) == 25 ether);
        assertTrue(
            mockGovERC20.totalSupply() ==
                50 ether + mockGovERC20.balanceOf(burner)
        );

        // Check resulting redeemed wETH.
        assertTrue(mockWeth.balanceOf(bob) == 2.5 ether);
        assertTrue(mockWeth.balanceOf(treasury) == 5 ether);

        // Mock alice to redeem gov for wETH.
        startHoax(alice, alice, type(uint256).max);
        router.ragequit(treasury, singleAsset, 25 ether);
        vm.stopPrank();

        // Check resulting gov balances.
        assertTrue(mockGovERC20.balanceOf(alice) == 0 ether);
        assertTrue(
            mockGovERC20.totalSupply() ==
                25 ether + mockGovERC20.balanceOf(burner)
        );

        // Check resulting redeemed wETH.
        assertTrue(mockWeth.balanceOf(alice) == 5 ether);
        assertTrue(mockWeth.balanceOf(treasury) == 2.5 ether);

        // Expect revert in underflow for Alice repeat.
        startHoax(alice, alice, type(uint256).max);
        vm.expectRevert(0x7939f424);
        router.ragequit(treasury, singleAsset, 25 ether);
        vm.stopPrank();

        // Mock bob to redeem gov for wETH.
        // This completes redemption.
        startHoax(bob, bob, type(uint256).max);
        router.ragequit(treasury, singleAsset, 25 ether);
        vm.stopPrank();

        // Check resulting gov balances.
        assertTrue(mockGovERC20.balanceOf(bob) == 0 ether);
        assertTrue(
            mockGovERC20.totalSupply() ==
                0 ether + mockGovERC20.balanceOf(burner)
        );

        // Check resulting redeemed wETH.
        assertTrue(mockWeth.balanceOf(bob) == 5 ether);
        assertTrue(mockWeth.balanceOf(treasury) == 0 ether);
    }

    function testCompleteRedemptionNonBurnable() public payable {
        router.setRagequit(
            burner,
            address(mockGovERC20),
            Standard.ERC20,
            0,
            start
        );
        vm.warp(1641070800);

        // Check initial gov balances.
        assertTrue(mockGovERC20.balanceOf(alice) == 50 ether);
        assertTrue(mockGovERC20.balanceOf(bob) == 50 ether);
        assertTrue(mockGovERC20.totalSupply() == 100 ether);

        // Check initial unredeemed wETH.
        assertTrue(mockWeth.balanceOf(alice) == 0 ether);
        assertTrue(mockWeth.balanceOf(bob) == 0 ether);
        assertTrue(mockWeth.balanceOf(treasury) == 10 ether);

        // Set up wETH claim.
        address[] memory singleAsset = new address[](1);
        singleAsset[0] = address(mockWeth);

        // Mock alice to redeem gov for wETH.
        startHoax(alice, alice, type(uint256).max);
        router.ragequit(treasury, singleAsset, 50 ether);
        vm.stopPrank();

        // Check resulting gov balances.
        assertTrue(mockGovERC20.balanceOf(alice) == 0 ether);
        assertTrue(
            mockGovERC20.totalSupply() ==
                50 ether + mockGovERC20.balanceOf(burner)
        );

        // Check resulting redeemed wETH.
        assertTrue(mockWeth.balanceOf(alice) == 5 ether);
        assertTrue(mockWeth.balanceOf(treasury) == 5 ether);

        // Mock bob to redeem gov for wETH.
        // This completes redemption.
        startHoax(bob, bob, type(uint256).max);
        router.ragequit(treasury, singleAsset, 50 ether);
        vm.stopPrank();

        // Check resulting gov balances.
        assertTrue(mockGovERC20.balanceOf(bob) == 0 ether);
        assertTrue(
            mockGovERC20.totalSupply() ==
                0 ether + mockGovERC20.balanceOf(burner)
        );

        // Check resulting redeemed wETH.
        assertTrue(mockWeth.balanceOf(bob) == 5 ether);
        assertTrue(mockWeth.balanceOf(treasury) == 0 ether);
    }

    function testCannotRedeemEarlyNonBurnable() public payable {
        router.setRagequit(
            burner,
            address(mockGovERC20),
            Standard.ERC20,
            0,
            start
        );
        vm.warp(1641070800);

        // Check initial gov balances.
        assertTrue(mockGovERC20.balanceOf(alice) == 50 ether);
        assertTrue(mockGovERC20.balanceOf(bob) == 50 ether);
        assertTrue(mockGovERC20.totalSupply() == 100 ether);

        // Check initial unredeemed wETH.
        assertTrue(mockWeth.balanceOf(alice) == 0 ether);
        assertTrue(mockWeth.balanceOf(bob) == 0 ether);
        assertTrue(mockWeth.balanceOf(treasury) == 10 ether);

        // Set up wETH claim.
        address[] memory singleAsset = new address[](1);
        singleAsset[0] = address(mockWeth);

        // Mock alice to redeem gov for wETH too early.
        vm.warp(start - 1);
        vm.expectRevert(bytes4(keccak256("NotStarted()")));
        startHoax(alice, alice, type(uint256).max);
        router.ragequit(treasury, singleAsset, 50 ether);
        vm.stopPrank();

        // Check resulting gov balances.
        assertTrue(mockGovERC20.balanceOf(alice) == 50 ether);
        assertTrue(mockGovERC20.totalSupply() == 100 ether);

        // Check resulting redeemed wETH.
        assertTrue(mockWeth.balanceOf(alice) == 0 ether);
        assertTrue(mockWeth.balanceOf(treasury) == 10 ether);
    }

    function testCannotRedeemMultiAssetOutOfOrderNonBurnable() public payable {
        router.setRagequit(
            burner,
            address(mockGovERC20),
            Standard.ERC20,
            0,
            start
        );
        vm.warp(1641070800);

        // Check initial gov balances.
        assertTrue(mockGovERC20.balanceOf(alice) == 50 ether);
        assertTrue(mockGovERC20.totalSupply() == 100 ether);

        // Check initial unredeemed wETH.
        assertTrue(mockWeth.balanceOf(alice) == 0 ether);
        assertTrue(mockWeth.balanceOf(treasury) == 10 ether);

        // Check initial unredeemed Dai.
        assertTrue(mockDai.balanceOf(alice) == 0 ether);
        assertTrue(mockDai.balanceOf(treasury) == 1000 ether);

        // Set up wETH/Dai claim.
        address[] memory multiAsset = new address[](2);
        multiAsset[1] = address(mockDai);
        multiAsset[0] = address(mockWeth);

        // Mock alice to redeem gov for wETH/Dai.
        startHoax(alice, alice, type(uint256).max);
        vm.expectRevert(bytes4(keccak256("InvalidAssetOrder()")));
        router.ragequit(treasury, multiAsset, 25 ether);
        vm.stopPrank();

        // Check resulting gov balances.
        assertTrue(mockGovERC20.balanceOf(alice) == 50 ether);
        assertTrue(mockGovERC20.totalSupply() == 100 ether);

        // Check resulting redeemed wETH.
        assertTrue(mockWeth.balanceOf(alice) == 0 ether);
        assertTrue(mockWeth.balanceOf(treasury) == 10 ether);

        // Check resulting redeemed Dai.
        assertTrue(mockDai.balanceOf(alice) == 0 ether);
        assertTrue(mockDai.balanceOf(treasury) == 1000 ether);
    }
}
