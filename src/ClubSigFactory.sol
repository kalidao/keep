// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {Multicall} from './utils/Multicall.sol';

import {IClub} from './interfaces/IClub.sol';

import {ClubSig} from './ClubSig.sol';
import {LootERC20} from './LootERC20.sol';

import {ClonesWithImmutableArgs} from './libraries/ClonesWithImmutableArgs.sol';

/// @notice ClubSig Contract Factory
contract ClubSigFactory is Multicall, IClub {
    /// -----------------------------------------------------------------------
    /// Library Usage
    /// -----------------------------------------------------------------------

    using ClonesWithImmutableArgs for address;

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event SigDeployed(
        ClubSig indexed clubSig,
        LootERC20 indexed loot,
        Club[] club_,
        uint256 quorum,
        uint256 redemptionStart,
        bytes32 name,
        bytes32 symbol,
        bool signerPaused,
        bool lootPaused,
        string docs,
        string baseURI
    );

    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    error NullDeploy();

    /// -----------------------------------------------------------------------
    /// Immutable Parameters
    /// -----------------------------------------------------------------------
  
    ClubSig internal immutable clubMaster;
    LootERC20 internal immutable lootMaster;

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor(ClubSig clubMaster_, LootERC20 lootMaster_) {
        clubMaster = clubMaster_;
        lootMaster = lootMaster_;
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
        bool signerPaused_,
        bool lootPaused_,
        string memory docs_,
        string memory baseURI_
    ) external payable returns (ClubSig clubSig, LootERC20 loot) {
        clubSig = ClubSig(address(clubMaster).clone(abi.encodePacked(name_, symbol_)));

        loot = LootERC20(address(lootMaster).clone(abi.encodePacked(name_, symbol_)));
        
        loot.init(
            club_,
            lootPaused_,
            address(clubSig)
        );
        
        clubSig.init{value: msg.value}(
            address(loot),
            club_,
            quorum_,
            redemptionStart_,
            signerPaused_,
            docs_,
            baseURI_
        );
        
        emit SigDeployed(clubSig, loot, club_, quorum_, redemptionStart_, name_, symbol_, signerPaused_, lootPaused_, docs_, baseURI_);
    }
}
