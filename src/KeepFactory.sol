// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Multicallable, Call, Keep} from "./Keep.sol";
import {LibClone} from "./utils/LibClone.sol";

/// @notice Keep Factory.
contract KeepFactory is Multicallable {
    /// -----------------------------------------------------------------------
    /// Library Usage
    /// -----------------------------------------------------------------------

    using LibClone for address;

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event Deployed(address keep, bytes32 name, address[] signers, uint256 threshold);

    /// -----------------------------------------------------------------------
    /// Immutables
    /// -----------------------------------------------------------------------

    Keep internal immutable keepTemplate;

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor(Keep _keepTemplate) payable {
        keepTemplate = _keepTemplate;
    }

    /// -----------------------------------------------------------------------
    /// Deployment Logic
    /// -----------------------------------------------------------------------

    function determineKeep(bytes32 name) public view virtual returns (address) {
        return
            address(keepTemplate).predictDeterministicAddress(
                abi.encodePacked(name, uint40(block.chainid)),
                name,
                address(this)
            );
    }

    function deployKeep(
        bytes32 name // create2 salt.
        Call[] calldata calls,
        address[] calldata signers,
        uint256 threshold
    ) public payable virtual {
        Keep keep = Keep(
            address(keepTemplate).cloneDeterministic(
                abi.encodePacked(name, uint40(block.chainid)),
                name
            )
        );

        keep.initialize{value: msg.value}(calls, signers, threshold);

        emit Deployed(address(keep), name, signers, threshold);
    }
}
