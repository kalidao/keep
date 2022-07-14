// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

/// @dev Contracts
import {
    Call, 
    Multicall, 
    Keep
} from "./Keep.sol";

/// @dev Libraries
import {ClonesWithImmutableArgs} from "./libraries/ClonesWithImmutableArgs.sol";

/// @notice Keep Factory
contract KeepFactory is Multicall {
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
    
    Keep internal immutable keepMaster;

    /// -----------------------------------------------------------------------
    /// CONSTRUCTOR
    /// -----------------------------------------------------------------------

    constructor(Keep _keepMaster) payable {
        keepMaster = _keepMaster;
    }

    /// -----------------------------------------------------------------------
    /// DEPLOYMENT LOGIC
    /// -----------------------------------------------------------------------

    function determine(bytes32 name) public view virtual returns (
        address keep, bool deployed
    ) {   
        (keep, deployed) = address(keepMaster).
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
        Keep keep = Keep(
            address(keepMaster).clone
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

        keep.init{value: msg.value}(
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
