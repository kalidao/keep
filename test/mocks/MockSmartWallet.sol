// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {MockERC1271Wallet} from "@solbase/test/utils/mocks/MockERC1271Wallet.sol";

contract MockSmartWallet is MockERC1271Wallet {
    constructor(address signer_) MockERC1271Wallet(signer_) {}
}

