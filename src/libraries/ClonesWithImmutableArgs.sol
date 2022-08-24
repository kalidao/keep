// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

/// @notice Enables creating clone contracts with immutable arguments
/// @author Modified from wighawag, zefram.eth, Saw-mon & Natalie, will@0xsplits.xyz
/// (https://github.com/wighawag/clones-with-immutable-args/blob/master/src/ClonesWithImmutableArgs.sol)
library ClonesWithImmutableArgs {
    error CREATE2_FAILED();

    uint256 private constant FREE_MEMORY_POINTER_SLOT = 0x40;
    uint256 private constant BOOTSTRAP_LENGTH = 0x6f;
    uint256 private constant RUNTIME_BASE = 0x65; // BOOTSTRAP_LENGTH - 10 bytes
    uint256 private constant ONE_WORD = 0x20;
    // = keccak256("ReceiveETH(uint256)")
    uint256 private constant RECEIVE_EVENT_SIG =
        0x9e4ac34f21c619cefc926c8bd93b54bf5a39c7ab2127a895af1cc0691d7e3dff;

    /// @notice Creates a clone proxy of the implementation contract with immutable args
    /// @dev data cannot exceed 65535 bytes, since 2 bytes are used to store the data length
    /// @param implementation The implementation contract to clone
    /// @param data Encoded immutable args
    /// @return ptr The ptr to the clone's bytecode
    /// @return creationSize The size of the clone to be created
    function cloneCreationCode(address implementation, bytes memory data)
        internal
        pure
        returns (uint256 ptr, uint256 creationSize)
    {
        // unrealistic for memory ptr or data length to exceed 256 bits
        assembly {
            let extraLength := add(mload(data), 2) // +2 bytes for telling how much data there is appended to the call
            creationSize := add(extraLength, BOOTSTRAP_LENGTH)
            let runSize := sub(creationSize, 0x0a)

            // free memory pointer
            ptr := mload(FREE_MEMORY_POINTER_SLOT)

            mstore(
                ptr,
                or(
                    hex"6100003d81600a3d39f336602f57343d527f", // 18 bytes
                    shl(0xe8, runSize)
                )
            )

            mstore(
                   add(ptr, 0x12), // 0x0 + 0x12
                RECEIVE_EVENT_SIG // 32 bytes
            )

            mstore(
                   add(ptr, 0x32), // 0x12 + 0x20
                or(
                    hex"60203da13d3df35b363d3d373d3d3d3d610000806000363936013d73", // 28 bytes
                    or(shl(0x68, extraLength), shl(0x50, RUNTIME_BASE))
                )
            )

            mstore(
                   add(ptr, 0x4e), // 0x32 + 0x1c
                shl(0x60, implementation) // 20 bytes
            )

            mstore(
                   add(ptr, 0x62), // 0x4e + 0x14
                hex"5af43d3d93803e606357fd5bf3" // 13 bytes
            )

            let counter := mload(data)
            let copyPtr := add(ptr, BOOTSTRAP_LENGTH)
            let dataPtr := add(data, ONE_WORD)

            for {} true {} {
                if lt(counter, ONE_WORD) { break }

                mstore(copyPtr, mload(dataPtr))

                copyPtr := add(copyPtr, ONE_WORD)
                dataPtr := add(dataPtr, ONE_WORD)

                counter := sub(counter, ONE_WORD)
            }

            let mask := shl(mul(0x8, sub(ONE_WORD, counter)), not(0))

            mstore(copyPtr, and(mload(dataPtr), mask))
            copyPtr := add(copyPtr, counter)
            mstore(copyPtr, shl(0xf0, extraLength))

            // update free memory pointer
            mstore(FREE_MEMORY_POINTER_SLOT, add(ptr, creationSize))
        }
    }

    /// @notice Creates a clone proxy of the implementation contract with immutable args
    /// @dev data cannot exceed 65535 bytes, since 2 bytes are used to store the data length
    /// @param implementation The implementation contract to clone
    /// @param salt The salt for create2
    /// @param data Encoded immutable args
    /// @return instance The address of the created clone
    function clone(
        address implementation,
        bytes32 salt,
        bytes memory data
    ) internal returns (address payable instance) {
        (uint256 creationPtr, uint256 creationSize) = cloneCreationCode(
            implementation,
            data
        );

        assembly {
            instance := create2(0, creationPtr, creationSize, salt)
        }
        
        // if create2 failed, the instance address won't be set
        if (instance == address(0)) {
            revert CREATE2_FAILED();
        }
    }

    /// @notice Predicts the address where a deterministic clone of implementation will be deployed
    /// @param implementation The implementation contract to clone
    /// @param salt The salt for create2
    /// @param data Encoded immutable args
    /// @return predicted The predicted address of the created clone
    /// @return exists Whether the clone already exists
    function predictDeterministicAddress(
        address implementation,
        bytes32 salt,
        bytes memory data
    ) internal view returns (address predicted, bool exists) {
        (uint256 creationPtr, uint256 creationSize) = cloneCreationCode(
            implementation,
            data
        );

        bytes32 creationHash;

        assembly {
            creationHash := keccak256(creationPtr, creationSize)
        }

        predicted = 
            address(
                uint160(
                    uint256(
                        keccak256(
                            abi.encodePacked(
                                bytes1(0xff), 
                                address(this), 
                                salt, 
                                creationHash
                            )
                        )
                    )
                )
            );

        exists = predicted.code.length != 0;
    }
}
