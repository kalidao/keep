// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {MockOwned} from "./mocks/MockOwned.sol";

import "@std/Test.sol";

contract OwnedTest is Test {
    MockOwned mockOwned;

    function setUp() public {
        mockOwned = new MockOwned();
    }

    function testSetOwner() public {
        testSetOwner(address(0xBEEF));
    }

    function testCallFunctionAsNonOwner() public {
        testCallFunctionAsNonOwner(address(0));
    }

    function testCallFunctionAsOwner() public {
        mockOwned.updateFlag();
    }

    function testSetOwner(address newOwner) public {
        mockOwned.transferOwnership(newOwner);

        assertEq(mockOwned.owner(), newOwner);
    }

    function testCallFunctionAsNonOwner(address owner) public {
        vm.assume(owner != address(this));

        mockOwned.transferOwnership(owner);

        vm.expectRevert(bytes4(keccak256("Unauthorized()")));
        mockOwned.updateFlag();
    }
}
