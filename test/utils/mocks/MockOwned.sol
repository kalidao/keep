// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Owned} from "../../../src/extensions/utils/Owned.sol";

contract MockOwned is Owned(msg.sender) {
    bool public flag;

    function updateFlag() public payable virtual onlyOwner {
        flag = true;
    }
}
