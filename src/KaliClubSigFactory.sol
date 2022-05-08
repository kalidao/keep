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
        (bytes32 lootDomain, bytes32 clubDomain) = determineDomains(name_, symbol_);
        // uniqueness is enforced on club name
        loot = ClubLoot(
            address(lootMaster)._clone(name_, abi.encodePacked(name_, symbol_, uint64(block.chainid), lootDomain))
        );

        clubSig = KaliClubSig(
            address(clubMaster)._clone(
                name_,
                abi.encodePacked(name_, symbol_, address(loot), uint64(block.chainid), clubDomain)
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
    
    function determineClones(
        bytes32 name, 
        bytes32 symbol
    ) public view returns (address loot, address club, bool deployed) {
        (loot, deployed) = address(lootMaster)._predictDeterministicAddress(
            name, abi.encodePacked(name, symbol, uint64(block.chainid)));
            
        (club, deployed) = address(clubMaster)._predictDeterministicAddress(
            name, abi.encodePacked(name, symbol, loot, uint64(block.chainid)));
    }

    function determineDomains(
        bytes32 name, 
        bytes32 symbol
    ) public view returns (bytes32 lootDomain, bytes32 clubDomain) {
        (address loot, address club, ) = determineClones(name, symbol);

        lootDomain = 
            keccak256(
                abi.encode(
                    keccak256(
                        'EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'
                    ),
                    abi.encodePacked(name, keccak256(bytes(' LOOT'))),
                    keccak256('1'),
                    block.chainid,
                    loot
                )
            );

        clubDomain = 
            keccak256(
                abi.encode(
                    keccak256(
                        'EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'
                    ),
                    name,
                    keccak256('1'),
                    block.chainid,
                    club
                )
            ); 
    }
}