// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {ReentrancyGuard} from "../src/extensions/utils/ReentrancyGuard.sol";

import "@std/Test.sol";

contract RiskyContract is ReentrancyGuard {
    uint256 public enterTimes;

    function unprotectedCall() public {
        enterTimes++;

        if (enterTimes > 1) {
            return;
        }

        this.protectedCall();
    }

    function protectedCall() public nonReentrant {
        enterTimes++;

        if (enterTimes > 1) {
            return;
        }

        this.protectedCall();
    }

    function overprotectedCall() public nonReentrant {}
}

contract ReentrancyGuardTest is Test {
    RiskyContract riskyContract;

    function setUp() public {
        riskyContract = new RiskyContract();
    }

    function invariantReentrancyStatusAlways1() public {
        assertEq(uint256(vm.load(address(riskyContract), 0)), 1);
    }

    function testFailUnprotectedCall() public {
        riskyContract.unprotectedCall();

        assertEq(riskyContract.enterTimes(), 1);
    }

    function testProtectedCall() public {
        try riskyContract.protectedCall() {
            fail("Reentrancy Guard Failed To Stop Attacker");
        } catch {}
    }

    function testNoReentrancy() public {
        riskyContract.overprotectedCall();
    }
}
