// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {Multicall} from '../utils/Multicall.sol';

import {IClubBYO} from '../interfaces/IClubBYO.sol';

import {ClubLootBYO} from './ClubLootBYO.sol';
import {KaliClubSigBYO} from './KaliClubSigBYO.sol';

import {ClonesWithImmutableArgs} from '../libraries/ClonesWithImmutableArgs.sol';

/// @notice Kali ClubSig (BYO) Contract Factory
contract KaliClubSigBYOfactory is Multicall, IClubBYO {
    /// -----------------------------------------------------------------------
    /// Library Usage
    /// -----------------------------------------------------------------------

    using ClonesWithImmutableArgs for address;

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event ClubDeployed(
        address indexed clubNFT_,
        ClubLootBYO indexed loot,
        KaliClubSigBYO indexed clubSig,
        Club[] club_,
        uint256 quorum,
        uint256 redemptionStart,
        bytes32 name,
        bytes32 symbol,
        bool lootPaused,
        string docs
    );

    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    error NullDeploy();

    /// -----------------------------------------------------------------------
    /// Immutable Parameters
    /// -----------------------------------------------------------------------

    ClubLootBYO private immutable lootMaster;
    KaliClubSigBYO private immutable clubMaster;

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor(ClubLootBYO lootMaster_, KaliClubSigBYO clubMaster_) {
        lootMaster = lootMaster_;
        clubMaster = clubMaster_;
    }

    /// -----------------------------------------------------------------------
    /// Deployment
    /// -----------------------------------------------------------------------

    function deployClubSig(
        address clubNFT_,
        Club[] calldata club_,
        uint256 quorum_,
        uint256 redemptionStart_,
        bytes32 name_,
        bytes32 symbol_,
        bool lootPaused_,
        string calldata docs_
    ) external payable returns (ClubLootBYO loot, KaliClubSigBYO clubSig) {
        loot = ClubLootBYO(
            address(lootMaster)._clone(name_, abi.encodePacked(name_, symbol_))
        );

        clubSig = KaliClubSigBYO(
            address(clubMaster)._clone(
                name_,
                abi.encodePacked(name_, symbol_, clubNFT_, address(loot))
            )
        );

        loot.init(address(clubSig), club_, lootPaused_);

        clubSig.init(quorum_, redemptionStart_, docs_);

        emit ClubDeployed(
            clubNFT_,
            loot,
            clubSig,
            club_,
            quorum_,
            redemptionStart_,
            name_,
            symbol_,
            lootPaused_,
            docs_
        );
    }
}
