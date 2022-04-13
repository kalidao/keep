// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {Multicall} from "./utils/Multicall.sol";

import {IClub} from "./interfaces/IClub.sol";
import {IRicardianLLC} from "./interfaces/IRicardianLLC.sol";

import {KaliClubSig} from "./KaliClubSig.sol";
import {ClubLoot} from "./ClubLoot.sol";

import {ClonesWithImmutableArgs} from "./libraries/ClonesWithImmutableArgs.sol";

/// @notice Kali ClubSig Contract Factory
contract KaliClubSigFactory is Multicall, IClub {
    /// -----------------------------------------------------------------------
    /// Library Usage
    /// -----------------------------------------------------------------------

    using ClonesWithImmutableArgs for address;

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event ClubDeployed(
        KaliClubSig indexed clubSig,
        ClubLoot indexed loot,
        Club[] club_,
        uint256 quorum,
        uint256 redemptionStart,
        bytes32 name,
        bytes32 symbol,
        bool lootPaused,
        bool signerPaused,
        string baseURI,
        string docs
    );

    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    error NullDeploy();

    /// -----------------------------------------------------------------------
    /// Immutable Parameters
    /// -----------------------------------------------------------------------

    KaliClubSig private immutable clubMaster;
    ClubLoot private immutable lootMaster;
    IRicardianLLC private immutable ricardianLLC;

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor(
        KaliClubSig clubMaster_,
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
        Club[] calldata club_,
        uint256 quorum_,
        uint256 redemptionStart_,
        bytes32 name_,
        bytes32 symbol_,
        bool lootPaused_,
        bool signerPaused_,
        string memory baseURI_,
        string memory docs_
    ) external payable returns (KaliClubSig clubSig, ClubLoot loot) {
        loot = ClubLoot(
            address(lootMaster).clone(abi.encodePacked(name_, symbol_))
        );

        clubSig = KaliClubSig(
            address(clubMaster).clone(abi.encodePacked(name_, symbol_, address(loot)))
        );

        clubSig.init(
            club_,
            quorum_,
            redemptionStart_,
            signerPaused_,
            baseURI_,
            docs_
        );

        loot.init(address(clubSig), club_, lootPaused_);

        bytes memory docs = bytes(docs_);

        if (docs.length == 0) {
            ricardianLLC.mintLLC{value: msg.value}(address(clubSig));
        }

        emit ClubDeployed(
            clubSig,
            loot,
            club_,
            quorum_,
            redemptionStart_,
            name_,
            symbol_,
            lootPaused_,
            signerPaused_,
            baseURI_,
            docs_
        );
    }
}
