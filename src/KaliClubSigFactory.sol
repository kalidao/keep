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
        Call[] calls_,
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
        Call[] memory calls_,
        Club[] memory club_,
        uint256 quorum_,
        uint256 redemptionStart_,
        bytes32 name_,
        bytes32 symbol_,
        bool lootPaused_,
        bool signerPaused_,
        string memory baseURI_,
        string memory docs_
    ) external payable returns (ClubLoot loot, KaliClubSig clubSig) {
        // uniqueness is enforced on club name
        loot = ClubLoot(
            address(lootMaster)._clone(name_, abi.encodePacked(name_, symbol_, uint64(block.chainid)))
        );

        clubSig = KaliClubSig(
            address(clubMaster)._clone(
                name_,
                abi.encodePacked(name_, symbol_, address(loot), uint64(block.chainid))
            )
        );

        loot.init(address(clubSig), club_, lootPaused_);

        clubSig.init(
            calls_,
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
            calls_,
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
    
    function determineClones(
        bytes32 name, 
        bytes32 symbol
    ) external view returns (address loot, address club, bool deployed) {
        (loot, deployed) = address(lootMaster)._predictDeterministicAddress(
            name, abi.encodePacked(name, symbol, uint64(block.chainid)));
            
        (club, deployed) = address(clubMaster)._predictDeterministicAddress(
            name, abi.encodePacked(name, symbol, loot, uint64(block.chainid)));
    } 
}
