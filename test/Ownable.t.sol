// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {MockOwnable} from "./utils/mocks/MockOwnable.sol";

import "@std/Test.sol";

contract OwnableTest is Test, MockOwnable {
    MockOwnable immutable mockOwnable = new MockOwnable();

    function setUp() public payable {}

    function testTransferOwnership() public payable {
        testTransferOwnership(address(0xBEEF));
    }

    function testCallFunctionAsNonOwner() public payable {
        testCallFunctionAsNonOwner(address(0));
    }

    function testCallFunctionAsOwner() public payable {
        mockOwnable.updateFlag();
    }

    function testTransferOwnership(address newOwner) public payable {
        mockOwnable.transferOwnership(newOwner);

        assertEq(mockOwnable.owner(), newOwner);
    }

    function testCallFunctionAsNonOwner(address owner) public payable {
        vm.assume(owner != address(this));

        mockOwnable.transferOwnership(owner);

        vm.expectRevert(Unauthorized.selector);
        mockOwnable.updateFlag();
    }

    function testERC165Support() public payable {
        // ERC173 selector.
        assert(mockOwnable.supportsInterface(0x7f5828d0));
    }
}
