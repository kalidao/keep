// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {MockERC1271Wallet} from "@solady/test/utils/mocks/MockERC1271Wallet.sol";

import {ERC1155TokenReceiver} from "../../../src/KeepToken.sol";

contract MockContractWallet is MockERC1271Wallet, ERC1155TokenReceiver {
    constructor(address usr) payable MockERC1271Wallet(usr) {}

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) public payable virtual returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
