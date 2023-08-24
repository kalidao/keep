// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Multicallable, Call, Keep} from "./Keep.sol";
import {Owned} from "./extensions/utils/Owned.sol";

/// @notice Keep Factory.
contract KeepFactory is Multicallable, Owned(tx.origin) {
    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event Deployed(Keep indexed keep, uint256 threshold);

    /// -----------------------------------------------------------------------
    /// Custom Errors
    /// -----------------------------------------------------------------------

    /// @dev Unable to deploy the clone.
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
        return predictDeterministicAddress(name);
    }

    function deployKeep(
        bytes32 name, // create2 salt.
        Call[] calldata calls,
        address[] calldata signers,
        uint256 threshold
    ) public payable virtual returns (Keep keep) {
        keep = cloneDeterministic(name);

        Keep(keep).initialize{value: msg.value}(calls, signers, threshold);

        emit Deployed(keep, threshold);
    }

    /// -----------------------------------------------------------------------
    /// Clone Operations
    /// -----------------------------------------------------------------------

    /// @dev Deploys a deterministic clone of `keepTemplate`,
    /// using immutable argument `name` also as `salt`.
    function cloneDeterministic(bytes32 salt) internal returns (Keep instance) {
        Keep template = keepTemplate;
        assembly {
            // Compute the boundaries of the data and cache the memory slots around it.
            let data := mload(0x40)
            let dataLength := 0x60
            let dataEnd := add(data, dataLength)

            // Write the bytecode before the data.
            mstore(data, 0x5af43d3d93803e606057fd5bf3)
            // Write the address of the implementation.
            mstore(add(data, 0x0d), template)

            // Create the instance.
            instance := create2(0, data, dataLength, salt)

            // If `instance` is zero, revert.
            if iszero(instance) {
                // Store the function selector of `DeploymentFailed()`.
                mstore(0x00, 0x30116425)
                // Revert with (offset, size).
                revert(0x1c, 0x04)
            }
        }
    }

    /// @dev Returns the address of the deterministic clone of
    /// `keepTemplate` using immutable arguments encoded in `data`, with `salt`.
    function predictDeterministicAddress(
        bytes32 salt
    ) internal view returns (address predicted) {
        Keep template = keepTemplate;
        assembly {
            // Compute the boundaries of the data and cache the memory slots around it.
            let data := mload(0x40)
            let dataLength := 0x60
            let dataEnd := add(data, dataLength)

            // Write the bytecode before the data.
            mstore(data, 0x5af43d3d93803e606057fd5bf3)
            // Write the address of the implementation.
            mstore(add(data, 0x0d), template)

            // Compute and store the bytecode hash.
            mstore(0x35, keccak256(data, dataLength))
            mstore8(0x00, 0xff) // Write the prefix.
            mstore(0x01, shl(96, address()))
            mstore(0x15, salt)
            predicted := keccak256(0x00, 0x55)
        }
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
