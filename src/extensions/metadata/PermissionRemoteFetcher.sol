// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {UserOperation} from "../../Keep.sol";

struct Permission {
    uint256 validAfter;
    uint256 validUntil;
    address receiver;
    bytes4 func;
    uint256 allowance;
    uint256 maxUses;
}

/// @notice Remote permission fetcher for ERC4337.
contract PermissionRemoteFetcher {
    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 hash,
        uint256 missingAccountFunds
    ) public view virtual returns (uint256) {
        /*Permission memory permission = abi.decode(userOp.data, (Permission));

        if (permission.validAfter > block.timestamp) {
            return 1;
        }

        if (permission.validUntil < block.timestamp) {
            return 2;
        }

        if (permission.maxUses > 0) {
            if (permission.allowance == 0) {
                return 3;
            }

            if (permission.allowance < userOp.amount) {
                return 4;
            }
        }

        if (permission.receiver != address(0)) {
            if (permission.receiver != userOp.sender) {
                return 5;
            }
        }

        return 0;*/
    }
}
