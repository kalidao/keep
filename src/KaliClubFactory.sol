// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

/// @dev Contracts
import {
    Call, 
    Multicall, 
    KaliClub
} from "./KaliClub.sol";

/// @dev Libraries
import {ClonesWithImmutableArgs} from "./libraries/ClonesWithImmutableArgs.sol";

/// @notice Kali Club Factory
contract KaliClubFactory is Multicall {
    /// -----------------------------------------------------------------------
    /// LIBRARY USAGE
    /// -----------------------------------------------------------------------

    using ClonesWithImmutableArgs for address;

    /// -----------------------------------------------------------------------
    /// EVENTS
    /// -----------------------------------------------------------------------

    event ClubDeployed(
        Call[] calls,
        address[] signers,
        uint256 threshold,
        bytes32 name
    );

    /// -----------------------------------------------------------------------
    /// IMMUTABLES
    /// -----------------------------------------------------------------------
    
    KaliClub internal immutable clubMaster;

    /// -----------------------------------------------------------------------
    /// CONSTRUCTOR
    /// -----------------------------------------------------------------------

    constructor(KaliClub _clubMaster) payable {
        clubMaster = _clubMaster;
    }

    /// -----------------------------------------------------------------------
    /// DEPLOYMENT LOGIC
    /// -----------------------------------------------------------------------

    function determineClub(bytes32 name) public view virtual returns (
        address club, bool deployed
    ) {   
        (club, deployed) = address(clubMaster).
            _predictDeterministicAddress
                (
                    name, 
                    abi.encodePacked(
                        name, 
                        uint40(
                            block.chainid
                        )
                    )
                );
    } 

    function deployClub(
        Call[] calldata calls,
        address[] calldata signers,
        uint256 threshold,
        bytes32 name // salt
    ) public payable virtual {
        KaliClub club = KaliClub(
            address(clubMaster)._clone
                (
                    name,
                    abi.encodePacked(
                        name, 
                        uint40(
                            block.chainid
                        )
                    )
                )
            );

        club.init{value: msg.value}(
            calls,
            signers,
            threshold
        );

        emit ClubDeployed(
            calls,
            signers,
            threshold,
            name
        );
    }
}
