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

    bytes32 private constant lootByteHash = keccak256(type(ClubLoot).creationCode);
    bytes32 private constant clubByteHash = keccak256(type(KaliClubSig).creationCode);

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
            address(lootMaster).cloneDeterministic(abi.encodePacked(name_, symbol_, uint64(block.chainid)))
        );

        clubSig = KaliClubSig(
            address(clubMaster).cloneDeterministic(
                abi.encodePacked(name_, symbol_, address(loot), uint64(block.chainid))
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
    
    /// @dev returns the addresses where contracts will be stored
    function computeClones(bytes32 name, bytes32 symbol) external view returns (address loot, bool) {
        return address(loot).predictDeterministicAddress(abi.encodePacked(name, symbol, uint64(block.chainid)));
    }
    /*
    function computeClones(bytes32 name, bytes32 symbol) external view returns (address loot, address club, bool deployed) {
        bytes32 lootSalt = keccak256(abi.encodePacked(name, symbol, uint64(block.chainid)));
        bytes32 lootHash = keccak256(abi.encodePacked(bytes1(0xff), address(this), lootSalt, lootByteHash));
        loot = address(uint160(uint256(lootHash)));

        bytes32 clubSalt = keccak256(abi.encodePacked(name, symbol, loot, uint64(block.chainid)));
        bytes32 clubHash = keccak256(abi.encodePacked(bytes1(0xff), address(this), clubSalt, clubByteHash));
        club = address(uint160(uint256(clubHash)));

        if (club.code.length != 0) deployed = true;
    }*/
    
}
