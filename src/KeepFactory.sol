// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @dev Contracts.
import {Call, Multicallable, Keep} from "./Keep.sol";

/// @dev Libraries.
import {LibClone} from "@solbase/utils/LibClone.sol";

/// @notice Keep Factory.
contract KeepFactory is Multicallable {
    /// -----------------------------------------------------------------------
    /// LIBRARY USAGE
    /// -----------------------------------------------------------------------

    using LibClone for address;

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

    Keep internal immutable keepTemplate;

    /// -----------------------------------------------------------------------
    /// CONSTRUCTOR
    /// -----------------------------------------------------------------------

    constructor(Keep _keepTemplate) payable {
        keepTemplate = _keepTemplate;
    }

    /// -----------------------------------------------------------------------
    /// DEPLOYMENT LOGIC
    /// -----------------------------------------------------------------------

    function determineKeep(bytes32 name)
        public
        view
        virtual
        returns (address keep)
    {
        keep = address(keepTemplate).predictDeterministicAddress(
            abi.encodePacked(name, uint40(block.chainid)),
            name,
            address(this)
        );
    }

    function deployKeep(
        Call[] calldata calls,
        address[] calldata signers,
        uint256 threshold,
        bytes32 name // create2 salt.
    ) public payable virtual {
        Keep keep = Keep(
            address(keepTemplate).cloneDeterministic(
                abi.encodePacked(name, uint40(block.chainid)),
                name
            )
        );

        keep.initialize{value: msg.value}(calls, signers, threshold);

        emit Deployed(calls, signers, threshold, name);
    }
}
