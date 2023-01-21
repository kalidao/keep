// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {MockOwned} from "./utils/mocks/MockOwned.sol";

import "@std/Test.sol";

contract OwnedTest is Test, MockOwned {
    MockOwned mockOwned;

    function setUp() public payable {
        mockOwned = new MockOwned();
    }

    function testTransferOwnership() public payable {
        testTransferOwnership(address(0xBEEF));
    }

    function testCallFunctionAsNonOwner() public payable {
        testCallFunctionAsNonOwner(address(0));
    }

    function testCallFunctionAsOwner() public payable {
        mockOwned.updateFlag();
    }

    function testTransferOwnership(address newOwner) public payable {
        mockOwned.transferOwnership(newOwner);

        assertEq(mockOwned.owner(), newOwner);
    }

    function testCallFunctionAsNonOwner(address owner) public payable {
        vm.assume(owner != address(this));

        mockOwned.transferOwnership(owner);

        vm.expectRevert(Unauthorized.selector);
        mockOwned.updateFlag();
    }

    function testERC165Support() public payable {
        // ERC173 selector.
        assert(mockOwned.supportsInterface(0x7f5828d0));
    }
}
