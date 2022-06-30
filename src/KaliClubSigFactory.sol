// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {Call, KaliClubSig} from './KaliClubSig.sol';

import {IMember} from './interfaces/IMember.sol';

import {ClonesWithImmutableArgs} from './libraries/ClonesWithImmutableArgs.sol';

import {Multicall} from './utils/Multicall.sol';

/// @notice Kali ClubSig Factory
contract KaliClubSigFactory is IMember, Multicall {
    /// -----------------------------------------------------------------------
    /// Library Usage
    /// -----------------------------------------------------------------------

    using ClonesWithImmutableArgs for address;

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event ClubDeployed(
        Call[] calls,
        Member[] members,
        uint256 quorum,
        bytes32 name,
        bytes32 symbol,
        bool signerPaused,
        string baseURI
    );

    /// -----------------------------------------------------------------------
    /// Immutable Parameters
    /// -----------------------------------------------------------------------
    
    KaliClubSig private immutable clubMaster;

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor(KaliClubSig clubMaster_) payable {
        clubMaster = clubMaster_;
    }

    /// -----------------------------------------------------------------------
    /// Deployment
    /// -----------------------------------------------------------------------

    function deployClubSig(
        Call[] calldata calls_,
        Member[] calldata members_,
        uint256 quorum_,
        bytes32 name_,
        bytes32 symbol_,
        bool signerPaused_,
        string memory baseURI_
    ) external payable returns (KaliClubSig clubSig) {
        // uniqueness is enforced on club name
        clubSig = KaliClubSig(
            address(clubMaster)._clone(
                name_,
                abi.encodePacked(name_, symbol_, uint64(block.chainid))
            )
        );

        clubSig.init{value: msg.value}(
            calls_,
            members_,
            quorum_,
            signerPaused_,
            baseURI_
        );

        emit ClubDeployed(
            calls_,
            members_,
            quorum_,
            name_,
            symbol_,
            signerPaused_,
            baseURI_
        );
    }
    
    function determineClone(bytes32 name, bytes32 symbol) external view returns (address club, bool deployed) {   
        (club, deployed) = address(clubMaster)._predictDeterministicAddress(
            name, abi.encodePacked(name, symbol, uint64(block.chainid)));
    } 
}
