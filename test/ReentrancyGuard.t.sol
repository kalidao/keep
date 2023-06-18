// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {ReentrancyGuard} from "../src/extensions/utils/ReentrancyGuard.sol";

import "@std/Test.sol";

contract RiskyContract is ReentrancyGuard {
    uint256 public enterTimes;

    function unprotectedCall() public payable {
        unchecked {
            ++enterTimes;
        }

        if (enterTimes > 1) {
            return;
        }

        this.protectedCall();
    }

    function protectedCall() public payable nonReentrant {
        unchecked {
            ++enterTimes;
        }

        if (enterTimes > 1) {
            return;
        }

        this.protectedCall();
    }

    function overprotectedCall() public payable nonReentrant {}
}

contract ReentrancyGuardTest is Test {
    RiskyContract internal immutable riskyContract = new RiskyContract();

    function setUp() public payable {}

    function invariantReentrancyStatusAlways1() public payable {
        assertEq(uint256(vm.load(address(riskyContract), 0)), 1);
    }

    function testFailUnprotectedCall() public payable {
        riskyContract.unprotectedCall();

        assertEq(riskyContract.enterTimes(), 1);
    }

    function testProtectedCall() public payable {
        try riskyContract.protectedCall() {
            fail("Reentrancy Guard Failed To Stop Attacker");
        } catch {}
    }

    function testNoReentrancy() public payable {
        riskyContract.overprotectedCall();
    }
}
