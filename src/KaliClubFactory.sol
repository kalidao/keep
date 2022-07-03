// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {Call, KaliClub} from './KaliClub.sol';

import {IMember} from './interfaces/IMember.sol';

import {ClonesWithImmutableArgs} from './libraries/ClonesWithImmutableArgs.sol';

import {Multicall} from './utils/Multicall.sol';

/// @notice Kali ClubSig Factory
contract KaliClubFactory is IMember, Multicall {
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
    
    KaliClub private immutable clubMaster;

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor(KaliClub _clubMaster) payable {
        clubMaster = _clubMaster;
    }

    /// -----------------------------------------------------------------------
    /// Deployment
    /// -----------------------------------------------------------------------

    function deployClub(
        Call[] calldata calls,
        Member[] calldata members,
        uint256 quorum,
        bytes32 name,
        bytes32 symbol,
        bool signerPaused,
        string memory baseURI
    ) external payable returns (KaliClub club) {
        // uniqueness is enforced on club name
        club = KaliClubSig(
            address(clubMaster)._clone(
                name,
                abi.encodePacked(name, symbol, uint64(block.chainid))
            )
        );

        club.init{value: msg.value}(
            calls,
            members,
            quorum,
            signerPaused,
            baseURI
        );

        emit ClubDeployed(
            calls,
            members,
            quorum,
            name,
            symbol,
            signerPaused,
            baseURI
        );
    }
    
    function determineClone(bytes32 name, bytes32 symbol) external view returns (address club, bool deployed) {   
        (club, deployed) = address(clubMaster)._predictDeterministicAddress(
            name, abi.encodePacked(name, symbol, uint64(block.chainid)));
    } 
}
