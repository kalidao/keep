// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {Vm} from "@std/Vm.sol";
import {DSTest} from "@ds/test.sol";
import {stdCheats, stdError} from "@std/stdlib.sol";

contract DSTestPlus is DSTest, stdCheats {
    /// @dev Use forge-std Vm logic
    Vm public constant vm = Vm(HEVM_ADDRESS);
}