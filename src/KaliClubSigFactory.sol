// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {ClubLoot} from './ClubLoot.sol';
import {KaliClubSig} from './KaliClubSig.sol';

import {IClub} from './interfaces/IClub.sol';
import {IRicardianLLC} from './interfaces/IRicardianLLC.sol';

import {ClonesWithImmutableArgs} from './libraries/ClonesWithImmutableArgs.sol';

import {Multicall} from './utils/Multicall.sol';

/// @notice Kali ClubSig Factory
contract KaliClubSigFactory is IClub, Multicall {
    /// -----------------------------------------------------------------------
    /// Library Usage
    /// -----------------------------------------------------------------------

    using ClonesWithImmutableArgs for address;

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event ClubDeployed(
        ClubLoot indexed loot,
        KaliClubSig indexed clubSig,
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
    
    ClubLoot private immutable lootMaster;
    KaliClubSig private immutable clubMaster;
    IRicardianLLC private immutable ricardianLLC;

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor(
        ClubLoot lootMaster_,
        KaliClubSig clubMaster_,
        IRicardianLLC ricardianLLC_
    ) {
        lootMaster = lootMaster_;
        clubMaster = clubMaster_;
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
        string calldata baseURI_,
        string memory docs_
    ) external payable returns (ClubLoot loot, KaliClubSig clubSig) {
        // uniqueness is enforced on combined club name and symbol
        loot = ClubLoot(
            address(lootMaster).clone(abi.encodePacked(name_, symbol_))
        );

        clubSig = KaliClubSig(
            address(clubMaster).clone(
                abi.encodePacked(name_, symbol_, address(loot), block.chainid)
            )
        );

        loot.init(address(clubSig), club_, lootPaused_);

        clubSig.init(
            club_,
            quorum_,
            redemptionStart_,
            signerPaused_,
            baseURI_,
            docs_
        );

        if (bytes(docs_).length == 0)
            ricardianLLC.mintLLC{value: msg.value}(address(clubSig));

        emit ClubDeployed(
            loot,
            clubSig,
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
