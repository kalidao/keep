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

    event Deployed(address indexed keep, address[] signers, uint256 threshold);

    /// -----------------------------------------------------------------------
    /// Immutables
    /// -----------------------------------------------------------------------

    address internal immutable keepTemplate;

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor(address _keepTemplate) payable {
        keepTemplate = _keepTemplate;
    }

    /// -----------------------------------------------------------------------
    /// Deployment Logic
    /// -----------------------------------------------------------------------

    function determineKeep(bytes32 name) public view virtual returns (address) {
        return
            keepTemplate.predictDeterministicAddress(
                abi.encodePacked(name),
                name,
                address(this)
            );
    }

    function deployKeep(
        bytes32 name, // create2 salt.
        Call[] calldata calls,
        address[] calldata signers,
        uint256 threshold
    ) public payable virtual {
        address keep = keepTemplate.cloneDeterministic(
            abi.encodePacked(name),
            name
        );

        Keep(keep).initialize{value: msg.value}(calls, signers, threshold);

        emit Deployed(keep, signers, threshold);
    }
}
