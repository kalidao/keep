// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity >=0.8.4;

import './ClubSig.sol';
import '../libraries/ClonesWithImmutableArgs.sol';

/// @notice ClubSig Factory.
contract ClubSigFactory is Multicall, ClubSig {
    /// -----------------------------------------------------------------------
    /// Library usage
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
    /// Immutable parameters
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
    ) public payable virtual returns (ClubSig clubSig) {
        bytes memory data = abi.encodePacked(name_, symbol_);

        clubSig = ClubSig(address(clubMaster).clone(data));

        clubSig.init(
            club_,
            quorum_,
            paused_,
            baseURI_
        );

        emit SigDeployed(clubSig, club_, quorum_, name_, symbol_, paused_, baseURI_);
    }
}
