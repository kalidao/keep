// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {MockERC20} from "@solbase/test/utils/mocks/MockERC20.sol";
import {MockERC721} from "@solbase/test/utils/mocks/MockERC721.sol";
import {MockERC1155} from "@solbase/test/utils/mocks/MockERC1155.sol";

import {Call, Keep} from "../src/Keep.sol";
import {KeepFactory} from "../src/KeepFactory.sol";
import {Standard, TributeRouter} from "../src/extensions/tribute/TributeRouter.sol";

import "@std/Test.sol";

error InvalidETHTribute();

error AlreadyReleased();

error Unauthorized();

contract TributeRouterTest is Test, Keep(this) {
    MockERC20 internal mockDai;
    MockERC721 internal mockNFT;
    MockERC1155 internal mock1155;

    Keep internal keep;
    KeepFactory internal factory;

    TributeRouter internal tribute;

    Call[] internal calls;

    uint256 internal immutable MINT_KEY = uint32(keep.mint.selector);

    bytes32 internal constant mockName =
        0x5445535400000000000000000000000000000000000000000000000000000000;

    function setUp() public payable {
        // Setup mock assets.
        mockDai = new MockERC20("Dai", "Dai", 18);
        mockNFT = new MockERC721("NFT", "NFT");
        mock1155 = new MockERC1155();

        // Setup base.
        keep = new Keep(Keep(vm.addr(1)));
        factory = new KeepFactory(keep);
        tribute = new TributeRouter();

        // Setup Keep.
        address[] memory signers = new address[](1);
        signers[0] = vm.addr(1);

        keep = Keep(factory.determineKeep(mockName));
        factory.deployKeep(mockName, calls, signers, 1);

        // Enable tribute router via mint key.
        vm.prank(address(keep));
        keep.mint(address(tribute), MINT_KEY, 1, "");

        // Enable tribute manager via mint key.
        vm.prank(address(keep));
        keep.mint(vm.addr(1), MINT_KEY, 1, "");
    }

    function testTributeInETH(
        address from,
        uint88 tokenId,
        uint112 amount,
        uint96 forId,
        uint112 forAmount
    ) public payable {
        vm.assume(from != address(0));
        vm.assume(from.code.length == 0);
        amount = uint112(bound(amount, 0, type(uint88).max));

        // Check Keep ID balance.
        assertEq(keep.balanceOf(from, forId), 0);

        // Supply ETH for mock tribute.
        (bool sent, ) = from.call{value: amount}("");
        assert(sent);

        assertEq(from.balance, amount);
        assertEq(address(tribute).balance, 0);
        assertEq(address(keep).balance, 0);

        vm.prank(from);
        tribute.makeTribute{value: amount}(
            address(keep),
            address(0),
            Standard.ETH,
            tokenId,
            amount,
            forId,
            forAmount,
            0
        );

        assertEq(from.balance, 0);
        assertEq(address(tribute).balance, amount);
        assertEq(address(keep).balance, 0);

        vm.prank(vm.addr(1));
        tribute.releaseTribute(0, true);

        assertEq(from.balance, 0);
        assertEq(address(tribute).balance, 0);
        assertEq(address(keep).balance, amount);

        // Check Keep ID minted.
        assertEq(keep.balanceOf(from, forId), forAmount);
    }

    function testTributeInETHRefund(
        address from,
        uint88 tokenId,
        uint112 amount,
        uint96 forId,
        uint112 forAmount
    ) public payable {
        vm.assume(from != address(0));
        vm.assume(from.code.length == 0);
        amount = uint112(bound(amount, 0, type(uint88).max));

        // Check Keep ID balance.
        assertEq(keep.balanceOf(from, forId), 0);

        // Supply ETH for mock tribute.
        (bool sent, ) = from.call{value: amount}("");
        assert(sent);

        assertEq(from.balance, amount);
        assertEq(address(tribute).balance, 0);
        assertEq(address(keep).balance, 0);

        vm.prank(from);
        tribute.makeTribute{value: amount}(
            address(keep),
            address(0),
            Standard.ETH,
            tokenId,
            amount,
            forId,
            forAmount,
            0
        );

        assertEq(from.balance, 0);
        assertEq(address(tribute).balance, amount);
        assertEq(address(keep).balance, 0);

        vm.prank(vm.addr(1));
        tribute.releaseTribute(0, false);

        assertEq(from.balance, amount);
        assertEq(address(tribute).balance, 0);
        assertEq(address(keep).balance, 0);

        // Check no Keep ID minted.
        assertEq(keep.balanceOf(from, forId), 0);
    }

    function testTributeInERC20(
        address from,
        uint88 tokenId,
        uint112 amount,
        uint96 forId,
        uint112 forAmount
    ) public payable {
        vm.assume(from != address(0));
        vm.assume(from.code.length == 0);
        amount = uint112(bound(amount, 0, type(uint88).max));

        // Check Keep ID balance.
        assertEq(keep.balanceOf(from, forId), 0);

        // Supply Dai for mock tribute.
        mockDai.mint(from, amount);

        assertEq(mockDai.balanceOf(from), amount);
        assertEq(mockDai.balanceOf(address(tribute)), 0);
        assertEq(mockDai.balanceOf(address(keep)), 0);

        vm.prank(from);
        mockDai.approve(address(tribute), amount);
        vm.prank(from);
        tribute.makeTribute(
            address(keep),
            address(mockDai),
            Standard.ERC20,
            tokenId,
            amount,
            forId,
            forAmount,
            0
        );

        assertEq(mockDai.balanceOf(from), 0);
        assertEq(mockDai.balanceOf(address(tribute)), amount);
        assertEq(mockDai.balanceOf(address(keep)), 0);

        vm.prank(vm.addr(1));
        tribute.releaseTribute(0, true);

        assertEq(mockDai.balanceOf(from), 0);
        assertEq(mockDai.balanceOf(address(tribute)), 0);
        assertEq(mockDai.balanceOf(address(keep)), amount);

        // Check Keep ID minted.
        assertEq(keep.balanceOf(from, forId), forAmount);
    }

    function testTributeInERC20Refund(
        address from,
        uint88 tokenId,
        uint112 amount,
        uint96 forId,
        uint112 forAmount
    ) public payable {
        vm.assume(from != address(0));
        vm.assume(from.code.length == 0);
        amount = uint112(bound(amount, 0, type(uint88).max));

        // Check Keep ID balance.
        assertEq(keep.balanceOf(from, forId), 0);

        // Supply Dai for mock tribute.
        mockDai.mint(from, amount);

        assertEq(mockDai.balanceOf(from), amount);
        assertEq(mockDai.balanceOf(address(tribute)), 0);
        assertEq(mockDai.balanceOf(address(keep)), 0);

        vm.prank(from);
        mockDai.approve(address(tribute), amount);
        vm.prank(from);
        tribute.makeTribute(
            address(keep),
            address(mockDai),
            Standard.ERC20,
            tokenId,
            amount,
            forId,
            forAmount,
            0
        );

        assertEq(mockDai.balanceOf(from), 0);
        assertEq(mockDai.balanceOf(address(tribute)), amount);
        assertEq(mockDai.balanceOf(address(keep)), 0);

        vm.prank(vm.addr(1));
        tribute.releaseTribute(0, false);

        assertEq(mockDai.balanceOf(from), amount);
        assertEq(mockDai.balanceOf(address(tribute)), 0);
        assertEq(mockDai.balanceOf(address(keep)), 0);

        // Check no Keep ID minted.
        assertEq(keep.balanceOf(from, forId), 0);
    }

    function testTributeInERC721(
        address from,
        uint88 tokenId,
        uint112 amount,
        uint96 forId,
        uint112 forAmount
    ) public payable {
        vm.assume(from != address(0));
        vm.assume(from.code.length == 0);
        amount = uint112(bound(amount, 0, type(uint88).max));

        // Check Keep ID balance.
        assertEq(keep.balanceOf(from, forId), 0);

        // Supply NFT for mock tribute.
        mockNFT.mint(from, tokenId);

        assertEq(mockNFT.balanceOf(from), 1);
        assertEq(mockNFT.balanceOf(address(tribute)), 0);
        assertEq(mockNFT.balanceOf(address(keep)), 0);

        vm.prank(from);
        mockNFT.approve(address(tribute), tokenId);
        vm.prank(from);
        tribute.makeTribute(
            address(keep),
            address(mockNFT),
            Standard.ERC721,
            tokenId,
            amount,
            forId,
            forAmount,
            0
        );

        assertEq(mockNFT.balanceOf(from), 0);
        assertEq(mockNFT.balanceOf(address(tribute)), 1);
        assertEq(mockNFT.balanceOf(address(keep)), 0);

        vm.prank(vm.addr(1));
        tribute.releaseTribute(0, true);

        assertEq(mockNFT.balanceOf(from), 0);
        assertEq(mockNFT.balanceOf(address(tribute)), 0);
        assertEq(mockNFT.balanceOf(address(keep)), 1);

        // Check Keep ID minted.
        assertEq(keep.balanceOf(from, forId), forAmount);
    }

    function testTributeInERC721Refund(
        address from,
        uint88 tokenId,
        uint112 amount,
        uint96 forId,
        uint112 forAmount
    ) public payable {
        vm.assume(from != address(0));
        vm.assume(from.code.length == 0);
        amount = uint112(bound(amount, 0, type(uint88).max));

        // Check Keep ID balance.
        assertEq(keep.balanceOf(from, forId), 0);

        // Supply NFT for mock tribute.
        mockNFT.mint(from, tokenId);

        assertEq(mockNFT.balanceOf(from), 1);
        assertEq(mockNFT.balanceOf(address(tribute)), 0);
        assertEq(mockNFT.balanceOf(address(keep)), 0);

        vm.prank(from);
        mockNFT.approve(address(tribute), tokenId);
        vm.prank(from);
        tribute.makeTribute(
            address(keep),
            address(mockNFT),
            Standard.ERC721,
            tokenId,
            amount,
            forId,
            forAmount,
            0
        );

        assertEq(mockNFT.balanceOf(from), 0);
        assertEq(mockNFT.balanceOf(address(tribute)), 1);
        assertEq(mockNFT.balanceOf(address(keep)), 0);

        vm.prank(vm.addr(1));
        tribute.releaseTribute(0, false);

        assertEq(mockNFT.balanceOf(from), 1);
        assertEq(mockNFT.balanceOf(address(tribute)), 0);
        assertEq(mockNFT.balanceOf(address(keep)), 0);

        // Check no Keep ID minted.
        assertEq(keep.balanceOf(from, forId), 0);
    }

    function testTributeInERC1155(
        address from,
        uint88 tokenId,
        uint112 amount,
        uint96 forId,
        uint112 forAmount
    ) public payable {
        vm.assume(from != address(0));
        vm.assume(from.code.length == 0);
        amount = uint112(bound(amount, 0, type(uint88).max));

        // Check Keep ID balance.
        assertEq(keep.balanceOf(from, forId), 0);

        // Supply NFT for mock tribute.
        mock1155.mint(from, tokenId, amount, "");

        assertEq(mock1155.balanceOf(from, tokenId), amount);
        assertEq(mock1155.balanceOf(address(tribute), tokenId), 0);
        assertEq(mock1155.balanceOf(address(keep), tokenId), 0);

        vm.prank(from);
        mock1155.setApprovalForAll(address(tribute), true);
        vm.prank(from);
        tribute.makeTribute(
            address(keep),
            address(mock1155),
            Standard.ERC1155,
            tokenId,
            amount,
            forId,
            forAmount,
            0
        );

        assertEq(mock1155.balanceOf(from, tokenId), 0);
        assertEq(mock1155.balanceOf(address(tribute), tokenId), amount);
        assertEq(mock1155.balanceOf(address(keep), tokenId), 0);

        vm.prank(vm.addr(1));
        tribute.releaseTribute(0, true);

        assertEq(mock1155.balanceOf(from, tokenId), 0);
        assertEq(mock1155.balanceOf(address(tribute), tokenId), 0);
        assertEq(mock1155.balanceOf(address(keep), tokenId), amount);

        // Check Keep ID minted.
        assertEq(keep.balanceOf(from, forId), forAmount);
    }

    function testTributeInERC1155Refund(
        address from,
        uint88 tokenId,
        uint112 amount,
        uint96 forId,
        uint112 forAmount
    ) public payable {
        vm.assume(from != address(0));
        vm.assume(from.code.length == 0);
        amount = uint112(bound(amount, 0, type(uint88).max));

        // Check Keep ID balance.
        assertEq(keep.balanceOf(from, forId), 0);

        // Supply NFT for mock tribute.
        mock1155.mint(from, tokenId, amount, "");

        assertEq(mock1155.balanceOf(from, tokenId), amount);
        assertEq(mock1155.balanceOf(address(tribute), tokenId), 0);
        assertEq(mock1155.balanceOf(address(keep), tokenId), 0);

        vm.prank(from);
        mock1155.setApprovalForAll(address(tribute), true);
        vm.prank(from);
        tribute.makeTribute(
            address(keep),
            address(mock1155),
            Standard.ERC1155,
            tokenId,
            amount,
            forId,
            forAmount,
            0
        );

        assertEq(mock1155.balanceOf(from, tokenId), 0);
        assertEq(mock1155.balanceOf(address(tribute), tokenId), amount);
        assertEq(mock1155.balanceOf(address(keep), tokenId), 0);

        vm.prank(vm.addr(1));
        tribute.releaseTribute(0, false);

        assertEq(mock1155.balanceOf(from, tokenId), amount);
        assertEq(mock1155.balanceOf(address(tribute), tokenId), 0);
        assertEq(mock1155.balanceOf(address(keep), tokenId), 0);

        // Check Keep ID minted.
        assertEq(keep.balanceOf(from, forId), 0);
    }

    function testReleaseTributeAsKeep(
        address from,
        uint88 tokenId,
        uint112 amount,
        uint96 forId,
        uint112 forAmount
    ) public payable {
        vm.assume(from != address(0));
        vm.assume(from.code.length == 0);
        amount = uint112(bound(amount, 0, type(uint88).max));

        // Check Keep ID balance.
        assertEq(keep.balanceOf(from, forId), 0);

        // Supply ETH for mock tribute.
        (bool sent, ) = from.call{value: amount}("");
        assert(sent);

        assertEq(from.balance, amount);
        assertEq(address(tribute).balance, 0);
        assertEq(address(keep).balance, 0);

        vm.prank(from);
        tribute.makeTribute{value: amount}(
            address(keep),
            address(0),
            Standard.ETH,
            tokenId,
            amount,
            forId,
            forAmount,
            0
        );

        assertEq(from.balance, 0);
        assertEq(address(tribute).balance, amount);
        assertEq(address(keep).balance, 0);

        vm.prank(address(keep));
        tribute.releaseTribute(0, true);

        assertEq(from.balance, 0);
        assertEq(address(tribute).balance, 0);
        assertEq(address(keep).balance, amount);

        // Check Keep ID minted.
        assertEq(keep.balanceOf(from, forId), forAmount);
    }

    /// @dev Adverse cases.

    function testCannotMakeETHTributeWithInvalidETH(
        address from,
        uint88 tokenId,
        uint112 amount,
        uint96 forId,
        uint112 forAmount
    ) public payable {
        vm.assume(from != address(0));
        vm.assume(from.code.length == 0);
        vm.assume(amount > 1);
        vm.assume(amount <= type(uint88).max);

        // Check Keep ID balance.
        assertEq(keep.balanceOf(from, forId), 0);

        // Supply ETH for mock tribute.
        (bool sent, ) = from.call{value: amount}("");
        assert(sent);

        assertEq(from.balance, amount);
        assertEq(address(tribute).balance, 0);
        assertEq(address(keep).balance, 0);

        vm.prank(from);
        vm.expectRevert(InvalidETHTribute.selector);
        tribute.makeTribute{value: amount - 1}(
            address(keep),
            address(0),
            Standard.ETH,
            tokenId,
            amount,
            forId,
            forAmount,
            0
        );

        // Check no release.
        assertEq(from.balance, amount);
        assertEq(address(tribute).balance, 0);
        assertEq(address(keep).balance, 0);

        // Check no Keep ID minted.
        assertEq(keep.balanceOf(from, forId), 0);
    }

    function testCannotMakeETHTributeWithInvalidStandard(
        address from,
        uint88 tokenId,
        uint112 amount,
        uint96 forId,
        uint112 forAmount
    ) public payable {
        vm.assume(from != address(0));
        vm.assume(from.code.length == 0);
        vm.assume(amount != 0);
        vm.assume(amount <= type(uint88).max);

        // Check Keep ID balance.
        assertEq(keep.balanceOf(from, forId), 0);

        // Supply ETH for mock tribute.
        (bool sent, ) = from.call{value: amount}("");
        assert(sent);

        assertEq(from.balance, amount);
        assertEq(address(tribute).balance, 0);
        assertEq(address(keep).balance, 0);

        vm.prank(from);
        vm.expectRevert(InvalidETHTribute.selector);
        tribute.makeTribute{value: amount}(
            address(keep),
            address(0),
            Standard.ERC20,
            tokenId,
            amount,
            forId,
            forAmount,
            0
        );

        vm.expectRevert(InvalidETHTribute.selector);
        tribute.makeTribute{value: amount}(
            address(keep),
            address(0),
            Standard.ERC721,
            tokenId,
            amount,
            forId,
            forAmount,
            0
        );

        vm.expectRevert(InvalidETHTribute.selector);
        tribute.makeTribute{value: amount}(
            address(keep),
            address(0),
            Standard.ERC1155,
            tokenId,
            amount,
            forId,
            forAmount,
            0
        );

        // Check no release.
        assertEq(from.balance, amount);
        assertEq(address(tribute).balance, 0);
        assertEq(address(keep).balance, 0);

        // Check no Keep ID minted.
        assertEq(keep.balanceOf(from, forId), 0);
    }

    function testCannotReleaseTributeMoreThanOnce(
        address from,
        uint88 tokenId,
        uint112 amount,
        uint96 forId,
        uint112 forAmount
    ) public payable {
        vm.assume(from != address(0));
        vm.assume(from.code.length == 0);
        amount = uint112(bound(amount, 0, type(uint88).max));

        // Check Keep ID balance.
        assertEq(keep.balanceOf(from, forId), 0);

        // Supply ETH for mock tribute.
        (bool sent, ) = from.call{value: amount}("");
        assert(sent);

        assertEq(from.balance, amount);
        assertEq(address(tribute).balance, 0);
        assertEq(address(keep).balance, 0);

        vm.prank(from);
        tribute.makeTribute{value: amount}(
            address(keep),
            address(0),
            Standard.ETH,
            tokenId,
            amount,
            forId,
            forAmount,
            0
        );

        assertEq(from.balance, 0);
        assertEq(address(tribute).balance, amount);
        assertEq(address(keep).balance, 0);

        vm.prank(vm.addr(1));
        tribute.releaseTribute(0, true);

        assertEq(from.balance, 0);
        assertEq(address(tribute).balance, 0);
        assertEq(address(keep).balance, amount);

        // Check Keep ID minted.
        assertEq(keep.balanceOf(from, forId), forAmount);

        vm.prank(vm.addr(1));
        vm.expectRevert(AlreadyReleased.selector);
        tribute.releaseTribute(0, true);

        assertEq(from.balance, 0);
        assertEq(address(tribute).balance, 0);
        assertEq(address(keep).balance, amount);
    }

    function testCannotReleaseTributeWithoutKey(
        address from,
        uint88 tokenId,
        uint112 amount,
        uint96 forId,
        uint112 forAmount
    ) public payable {
        vm.assume(from != address(0));
        vm.assume(from.code.length == 0);
        amount = uint112(bound(amount, 0, type(uint88).max));

        // Check Keep ID balance.
        assertEq(keep.balanceOf(from, forId), 0);

        // Supply ETH for mock tribute.
        (bool sent, ) = from.call{value: amount}("");
        assert(sent);

        assertEq(from.balance, amount);
        assertEq(address(tribute).balance, 0);
        assertEq(address(keep).balance, 0);

        vm.prank(from);
        tribute.makeTribute{value: amount}(
            address(keep),
            address(0),
            Standard.ETH,
            tokenId,
            amount,
            forId,
            forAmount,
            0
        );

        assertEq(from.balance, 0);
        assertEq(address(tribute).balance, amount);
        assertEq(address(keep).balance, 0);

        vm.expectRevert(Unauthorized.selector);
        vm.prank(vm.addr(2));
        tribute.releaseTribute(0, true);

        // Check no release.
        assertEq(from.balance, 0);
        assertEq(address(tribute).balance, amount);
        assertEq(address(keep).balance, 0);

        // Check no Keep ID minted,
        assertEq(keep.balanceOf(from, forId), 0);
    }
}
