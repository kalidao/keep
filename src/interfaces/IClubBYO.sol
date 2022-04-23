// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

/// @notice Kali ClubSigBYO membership interface
interface IClubBYO {
    struct Club {
        address signer;
        uint256 loot;
    }
}
