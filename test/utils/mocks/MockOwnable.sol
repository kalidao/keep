// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Ownable} from "../../../src/utils/Ownable.sol";

contract MockOwnable is Ownable(msg.sender) {
    bool public flag;

    function updateFlag() public payable virtual onlyOwner {
        flag = true;
    }
}
