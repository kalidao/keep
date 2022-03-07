// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {ClubSig} from './ClubSig.sol';

import {Multicall} from './utils/Multicall.sol';

import {ClonesWithImmutableArgs} from './libraries/ClonesWithImmutableArgs.sol';

/// @notice ClubSig Contract Factory
contract ClubSigFactory is Multicall, ClubSig {
    /// -----------------------------------------------------------------------
    /// Library Usage
    /// -----------------------------------------------------------------------

    using ClonesWithImmutableArgs for address;

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event SigDeployed(
        ClubSig indexed clubSig,
        Club[] club_,
        uint256 quorum,
        bytes32 name,
        bytes32 symbol,
        bool paused,
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

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor(ClubSig clubMaster_) {
        clubMaster = clubMaster_;
    }

    /// -----------------------------------------------------------------------
    /// Deployment
    /// -----------------------------------------------------------------------

    function deployClubSig(
        Club[] calldata club_,
        uint256 quorum_,
        bytes32 name_,
        bytes32 symbol_,
        bool paused_,
        string calldata baseURI_
    ) public payable returns (ClubSig clubSig) {
        bytes memory data = abi.encodePacked(name_, symbol_);

        clubSig = ClubSig(address(clubMaster).clone(data));

        clubSig.init{msg.value}(
            club_,
            quorum_,
            paused_,
            baseURI_
        );

        emit SigDeployed(clubSig, club_, quorum_, name_, symbol_, paused_, baseURI_);
    }
}
