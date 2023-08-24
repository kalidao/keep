// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Multicallable, Call, Keep} from "./Keep.sol";
import {Owned} from "./extensions/utils/Owned.sol";
import {LibClone} from "./utils/LibClone.sol";

/// @notice Keep Factory.
contract KeepFactory is Multicallable, Owned(tx.origin) {
    using LibClone for address;

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event Deployed(address indexed keep, uint256 threshold);

    /// -----------------------------------------------------------------------
    /// Custom Errors
    /// -----------------------------------------------------------------------

    error DeploymentFailed();

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
    ) public payable virtual returns (address keep) {
        keep = address(keepTemplate).cloneDeterministic(
            abi.encodePacked(name),
            name
        );

        Keep(keep).initialize{value: msg.value}(calls, signers, threshold);

        emit Deployed(keep, threshold);
    }

    /// -----------------------------------------------------------------------
    /// ERC4337 Staking Logic
    /// -----------------------------------------------------------------------

    function addStake(
        uint256 unstakeDelaySec
    ) public payable virtual onlyOwner {
        KeepFactory(keepTemplate.entryPoint()).addStake{value: msg.value}(
            unstakeDelaySec
        );
    }

    function unlockStake() public payable virtual onlyOwner {
        KeepFactory(keepTemplate.entryPoint()).unlockStake();
    }

    function withdrawStake(
        address withdrawAddress
    ) public payable virtual onlyOwner {
        KeepFactory(keepTemplate.entryPoint()).withdrawStake(withdrawAddress);
    }
}
