// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {Multicall} from "../utils/Multicall.sol";

import {IClub} from "../interfaces/IClub.sol";
import {IRicardianLLC} from "./interfaces/IRicardianLLC.sol";

import {KaliClubSig} from "../KaliClubSigBYO.sol";
import {ClubLoot} from "../ClubLoot.sol";

import {ClonesWithImmutableArgs} from "../libraries/ClonesWithImmutableArgs.sol";

/// @notice Kali ClubSig (BYO) Contract Factory
contract KaliClubSigBYOFactory is Multicall, IClub {
    /// -----------------------------------------------------------------------
    /// Library Usage
    /// -----------------------------------------------------------------------

    using ClonesWithImmutableArgs for address;

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event ClubDeployed(
        address indexed clubNFT_,
        KaliClubSigBYO indexed clubSig,
        ClubLoot indexed loot,
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

    KaliClubSigBYO private immutable clubMaster;
    ClubLoot private immutable lootMaster;
    IRicardianLLC private immutable ricardianLLC;

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor(
        KaliClubSigBYO clubMaster_,
        ClubLoot lootMaster_,
        IRicardianLLC ricardianLLC_
    ) {
        clubMaster = clubMaster_;
        lootMaster = lootMaster_;
        ricardianLLC = ricardianLLC_;
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
    ) external payable returns (KaliClubSigBYO clubSig, ClubLoot loot) {
        loot = ClubLoot(
            address(lootMaster).clone(abi.encodePacked(name_, symbol_))
        );

        clubSig = KaliClubSigBYO(
            address(clubMaster).clone(
                abi.encodePacked(name_, symbol_, clubNFT_, address(loot))
            )
        );

        clubSig.init(
            quorum_,
            redemptionStart_,
            docs_
        );

        loot.init(address(clubSig), club_, lootPaused_);

        if (bytes(docs_).length == 0) {
            ricardianLLC.mintLLC{value: msg.value}(address(clubSig));
        }

        emit ClubDeployed(
            clubNFT_,
            clubSig,
            loot,
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
