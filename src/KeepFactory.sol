// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Multicallable, Call, Keep} from "./Keep.sol";
import {Ownable} from "./utils/Ownable.sol";
import {Validator} from "./extensions/validate/Validator.sol";

/// @notice Keep Factory.
contract KeepFactory is Multicallable, Ownable(tx.origin) {
    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event Deployed(Keep indexed keep, uint256 quorum);

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

    constructor() payable {
        keepTemplate = new Keep(Keep(address(new Validator())));
    }

    /// -----------------------------------------------------------------------
    /// Deployment Logic
    /// -----------------------------------------------------------------------

    function deployKeep(
        bytes32 name, // create2 salt.
        Call[] calldata calls,
        address[] calldata signers,
        uint256 quorum
    ) public payable virtual returns (Keep keep) {
        bytes memory data = abi.encodePacked(name);
        address implementation = address(keepTemplate);

        assembly {
            // Compute the boundaries of the data and cache the memory slots around it.
            let mBefore3 := mload(sub(data, 0x60))
            let mBefore2 := mload(sub(data, 0x40))
            let mBefore1 := mload(sub(data, 0x20))
            let dataLength := mload(data)
            let dataEnd := add(add(data, 0x20), dataLength)
            let mAfter1 := mload(dataEnd)

            // +2 bytes for telling how much data there is appended to the call.
            let extraLength := add(dataLength, 2)

            // Write the bytecode before the data.
            mstore(data, 0x5af43d3d93803e606057fd5bf3)
            // Write the address of the implementation.
            mstore(sub(data, 0x0d), implementation)
            // Write the rest of the bytecode.
            mstore(
                sub(data, 0x21),
                or(
                    shl(0x48, extraLength),
                    0x593da1005b363d3d373d3d3d3d610000806062363936013d73
                )
            )
            // `keccak256("ReceiveETH(uint256)")`.
            mstore(
                sub(data, 0x3a),
                0x9e4ac34f21c619cefc926c8bd93b54bf5a39c7ab2127a895af1cc0691d7e3dff
            )
            mstore(
                // Do a out-of-gas revert if `extraLength` is too big. 0xffff - 0x62 + 0x01 = 0xff9e.
                // The actual EVM limit may be smaller and may change over time.
                sub(data, add(0x59, lt(extraLength, 0xff9e))),
                or(
                    shl(0x78, add(extraLength, 0x62)),
                    0xfd6100003d81600a3d39f336602c57343d527f
                )
            )
            mstore(dataEnd, shl(0xf0, extraLength))

            // Create the instance.
            keep := create2(
                callvalue(),
                sub(data, 0x4c),
                add(extraLength, 0x6c),
                name
            )

            // If `keep` is zero, revert.
            if iszero(keep) {
                // Store the function selector of `DeploymentFailed()`.
                mstore(0x00, 0x30116425)
                // Revert with (offset, size).
                revert(0x1c, 0x04)
            }

            // Restore the overwritten memory surrounding `data`.
            mstore(dataEnd, mAfter1)
            mstore(data, dataLength)
            mstore(sub(data, 0x20), mBefore1)
            mstore(sub(data, 0x40), mBefore2)
            mstore(sub(data, 0x60), mBefore3)
        }

        keep.initialize(calls, signers, quorum);

        emit Deployed(keep, quorum);
    }

    function determineKeep(
        bytes32 name
    ) public view virtual returns (address keep, bool deployed) {
        bytes memory data = abi.encodePacked(name);
        address implementation = address(keepTemplate);

        assembly {
            // Compute the boundaries of the data and cache the memory slots around it.
            let mBefore3 := mload(sub(data, 0x60))
            let mBefore2 := mload(sub(data, 0x40))
            let mBefore1 := mload(sub(data, 0x20))
            let dataLength := mload(data)
            let dataEnd := add(add(data, 0x20), dataLength)
            let mAfter1 := mload(dataEnd)

            // +2 bytes for telling how much data there is appended to the call.
            let extraLength := add(dataLength, 2)

            // Write the bytecode before the data.
            mstore(data, 0x5af43d3d93803e606057fd5bf3)
            // Write the address of the implementation.
            mstore(sub(data, 0x0d), implementation)
            // Write the rest of the bytecode.
            mstore(
                sub(data, 0x21),
                or(
                    shl(0x48, extraLength),
                    0x593da1005b363d3d373d3d3d3d610000806062363936013d73
                )
            )
            // `keccak256("ReceiveETH(uint256)")`.
            mstore(
                sub(data, 0x3a),
                0x9e4ac34f21c619cefc926c8bd93b54bf5a39c7ab2127a895af1cc0691d7e3dff
            )
            mstore(
                // Do a out-of-gas revert if `extraLength` is too big. 0xffff - 0x62 + 0x01 = 0xff9e.
                // The actual EVM limit may be smaller and may change over time.
                sub(data, add(0x59, lt(extraLength, 0xff9e))),
                or(
                    shl(0x78, add(extraLength, 0x62)),
                    0xfd6100003d81600a3d39f336602c57343d527f
                )
            )
            mstore(dataEnd, shl(0xf0, extraLength))

            // Compute and store the bytecode hash.
            mstore(0x35, keccak256(sub(data, 0x4c), add(extraLength, 0x6c)))
            mstore8(0x00, 0xff) // Write the prefix.
            mstore(0x01, shl(96, address()))
            mstore(0x15, name)
            keep := keccak256(0x00, 0x55)
            deployed := extcodesize(keep)
            // Restore the part of the free memory pointer that has been overwritten.
            mstore(0x35, 0)

            // Restore the overwritten memory surrounding `data`.
            mstore(dataEnd, mAfter1)
            mstore(data, dataLength)
            mstore(sub(data, 0x20), mBefore1)
            mstore(sub(data, 0x40), mBefore2)
            mstore(sub(data, 0x60), mBefore3)
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
