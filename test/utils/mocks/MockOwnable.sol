// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {Ownable} from "../../../src/utils/Ownable.sol";

contract MockOwnable is Ownable(msg.sender) {
    bool public flag;

    function updateFlag() public payable virtual onlyOwner {
        flag = true;
    }
}
