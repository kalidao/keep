// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Multicallable, Call, Keep} from "./Keep.sol";
import {Owned} from "./extensions/utils/Owned.sol";
import {Validator} from "./extensions/metadata/Validator.sol";

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

    Keep public immutable keepTemplate;

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor() payable {
        keepTemplate = new Keep(Keep(address(new Validator())));
    }

    /// -----------------------------------------------------------------------
    /// Deployment Logic
    /// -----------------------------------------------------------------------

    function deployKeep(
        bytes memory name, // create2 salt.
        Call[] calldata calls,
        address[] calldata signers,
        uint256 threshold
    ) public payable virtual returns (Keep keep) {
        address implementation = address(keepTemplate);

        assembly {
            // Compute the boundaries of the data and cache the memory slots around it.
            let mBefore3 := mload(sub(name, 0x60)) // subtract 96 bytes from data pointer
            let mBefore2 := mload(sub(name, 0x40)) // subtract 64 bytes from data pointer
            let mBefore1 := mload(sub(name, 0x20)) // subtract 32 bytes from data pointer
            let dataLength := mload(name) // the length of the data is in the first word for bytes

            if gt(dataLength, 0x20) {
                revert(0, 0)
            }

            let dataEnd := add(add(name, 0x20), dataLength) // skip over the length field to the actual data and add the length of the data to get the end of the data
            let mAfter1 := mload(dataEnd) // save whatever is in memory after the data

            // +2 bytes for telling how much data there is appended to the call.
            let extraLength := add(dataLength, 2)

            // Write the bytecode before the data.
            mstore(name, 0x5af43d3d93803e606057fd5bf3)
            // Write the address of the implementation.
            mstore(sub(name, 0x0d), implementation) // subtract 13 bytes from data pointer
            // Write the rest of the bytecode.
            mstore(
                sub(name, 0x21), // subtract 33 bytes from data pointer to get the offset
                or(
                    //
                    shl(0x48, extraLength), // shift 72 bytes left and bitwise or with extraLength
                    0x593da1005b363d3d373d3d3d3d610000806062363936013d73
                )
            )
            // `keccak256("ReceiveETH(uint256)")`.
            mstore(
                sub(name, 0x3a), // subtract 58 bytes from data pointer to get the offset
                0x9e4ac34f21c619cefc926c8bd93b54bf5a39c7ab2127a895af1cc0691d7e3dff
            )
            mstore(
                sub(name, 0x5a), // subtract 90 bytes from data pointer to get the offset
                or(
                    shl(0x78, add(extraLength, 0x62)), // shift 120 bytes left and bitwise or with extraLength + 98
                    0x6100003d81600a3d39f336602c57343d527f
                )
            )
            mstore(dataEnd, shl(0xf0, extraLength)) // shift 240 bytes left and store at dataEnd

            // Create the Keep.
            // value, offset, size, salt
            // offset is data - 76
            // size is extraLength + 108
            keep := create2(0, sub(name, 0x4c), add(extraLength, 0x6c), name)

            // If `keep` is zero, revert.
            if iszero(keep) {
                // Store the function selector of `DeploymentFailed()`.
                mstore(0x00, 0x30116425)
                // Revert with (offset, size).
                revert(0x1c, 0x04)
            }

            // Restore the overwritten memory surrounding `data`.
            mstore(dataEnd, mAfter1)
            mstore(name, dataLength)
            mstore(sub(name, 0x20), mBefore1)
            mstore(sub(name, 0x40), mBefore2)
            mstore(sub(name, 0x60), mBefore3)
        }

        keep.initialize{value: msg.value}(calls, signers, threshold);

        emit Deployed(keep, threshold);
    }

    function determineKeep(
        bytes memory name
    ) public view virtual returns (address keep, bool deployed) {
        address implementation = address(keepTemplate);

        assembly {
            // Compute the boundaries of the data and cache the memory slots around it.
            let mBefore3 := mload(sub(name, 0x60))
            let mBefore2 := mload(sub(name, 0x40))
            let mBefore1 := mload(sub(name, 0x20))
            let dataLength := mload(name)
            let dataEnd := add(add(name, 0x20), dataLength)
            let mAfter1 := mload(dataEnd)

            // +2 bytes for telling how much data there is appended to the call.
            let extraLength := add(dataLength, 2)

            // Write the bytecode before the data.
            mstore(name, 0x5af43d3d93803e606057fd5bf3)
            // Write the address of the implementation.
            mstore(sub(name, 0x0d), implementation)
            // Write the rest of the bytecode.
            mstore(
                sub(name, 0x21),
                or(
                    shl(0x48, extraLength),
                    0x593da1005b363d3d373d3d3d3d610000806062363936013d73
                )
            )
            // `keccak256("ReceiveETH(uint256)")`.
            mstore(
                sub(name, 0x3a),
                0x9e4ac34f21c619cefc926c8bd93b54bf5a39c7ab2127a895af1cc0691d7e3dff
            )
            mstore(
                sub(name, 0x5a),
                or(
                    shl(0x78, add(extraLength, 0x62)),
                    0x6100003d81600a3d39f336602c57343d527f
                )
            )
            mstore(dataEnd, shl(0xf0, extraLength))

            // Compute and store the bytecode hash.
            mstore(0x35, keccak256(sub(name, 0x4c), add(extraLength, 0x6c)))
            mstore8(0x00, 0xff) // Write the prefix.
            mstore(0x01, shl(96, address()))
            mstore(0x15, name)
            keep := keccak256(0x00, 0x55)
            deployed := extcodesize(keep)
            // Restore the part of the free memory pointer that has been overwritten.
            mstore(0x35, 0)

            // Restore the overwritten memory surrounding `data`.
            mstore(dataEnd, mAfter1)
            mstore(name, dataLength)
            mstore(sub(name, 0x20), mBefore1)
            mstore(sub(name, 0x40), mBefore2)
            mstore(sub(name, 0x60), mBefore3)
        }
    }

    /// -----------------------------------------------------------------------
    /// ERC4337 Staking Logic
    /// -----------------------------------------------------------------------

    function addStake(uint32 unstakeDelaySec) public payable virtual onlyOwner {
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
