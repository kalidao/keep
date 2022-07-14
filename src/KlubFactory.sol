// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

/// @dev Contracts
import {
    Call, 
    Multicall, 
    Klub
} from "./Klub.sol";

/// @dev Libraries
import {ClonesWithImmutableArgs} from "./libraries/ClonesWithImmutableArgs.sol";

/// @notice Klub Factory
contract KlubFactory is Multicall {
    /// -----------------------------------------------------------------------
    /// LIBRARY USAGE
    /// -----------------------------------------------------------------------

    using ClonesWithImmutableArgs for address;

    /// -----------------------------------------------------------------------
    /// EVENTS
    /// -----------------------------------------------------------------------

    event Deployed(
        Call[] calls,
        address[] signers,
        uint256 threshold,
        bytes32 name
    );

    /// -----------------------------------------------------------------------
    /// IMMUTABLES
    /// -----------------------------------------------------------------------
    
    Klub internal immutable klubMaster;

    /// -----------------------------------------------------------------------
    /// CONSTRUCTOR
    /// -----------------------------------------------------------------------

    constructor(Klub _klubMaster) payable {
        klubMaster = _klubMaster;
    }

    /// -----------------------------------------------------------------------
    /// DEPLOYMENT LOGIC
    /// -----------------------------------------------------------------------

    function determine(bytes32 name) public view virtual returns (
        address club, bool deployed
    ) {   
        (club, deployed) = address(klubMaster).
            predictDeterministicAddress
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

    function deploy(
        Call[] calldata calls,
        address[] calldata signers,
        uint256 threshold,
        bytes32 name // salt
    ) public payable virtual {
        Klub klub = Klub(
            address(klubMaster).clone
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

        klub.init{value: msg.value}(
            calls,
            signers,
            threshold
        );

        emit Deployed(
            calls,
            signers,
            threshold,
            name
        );
    }
}
