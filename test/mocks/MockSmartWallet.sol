// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {MockERC1271Wallet} from "@solbase/test/utils/mocks/MockERC1271Wallet.sol";
import {ERC1155TokenReceiver} from "../../src/Keep.sol";

contract MockSmartWallet is MockERC1271Wallet, ERC1155TokenReceiver {
    constructor(address signer_) MockERC1271Wallet(signer_) {}
}

