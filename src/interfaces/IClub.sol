// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

/// @notice Kali ClubSig membership interface
interface IClub {
    struct Club {
        address signer;
        uint256 id;
        uint256 loot;
    }
}
