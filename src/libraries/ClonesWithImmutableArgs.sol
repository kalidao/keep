// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

/// @notice Enables creating clone contracts with immutable arguments
/// @author Modified from wighawag, zefram.eth, Saw-mon & Natalie, will@0xsplits.xyz
/// (https://github.com/wighawag/clones-with-immutable-args/blob/master/src/ClonesWithImmutableArgs.sol)
library ClonesWithImmutableArgs {
    error CREATE2_FAILED();

    uint256 private constant FREE_MEMORY_POINTER_SLOT = 0x40;
    uint256 private constant BOOTSTRAP_LENGTH = 0x3f;
    uint256 private constant ONE_WORD = 0x20;

    /// @notice Creates a clone proxy of the implementation contract with immutable args
    /// @dev `data` cannot exceed 65535 bytes, since 2 bytes are used to store the data length
    /// @param implementation The implementation contract to clone
    /// @param data Encoded immutable args
    /// @return ptr The ptr to the clone's bytecode
    /// @return creationSize The size of the clone to be created
    function cloneCreationCode(address implementation, bytes memory data)
        internal
        pure
        virtual
        returns (uint256 ptr, uint256 creationSize)
    {
        assembly {
            let extraLength := add(mload(data), 2)
            creationSize := add(extraLength, BOOTSTRAP_LENGTH)
            let runSize := sub(creationSize, 0x0a)

            ptr := mload(FREE_MEMORY_POINTER_SLOT)
                
            mstore(
                ptr,
                or(
                    hex"610000_3d_81_600a_3d_39_f3_36_3d_3d_37_3d_3d_3d_3d_610000_80_6035_36_39_36_01_3d_73",
                    or(
                        shl(0xe8, runSize),
                        shl(0x58, extraLength)
                    )
                )
            )
                
            mstore(
                add(ptr, 0x1e),
                shl(0x60, implementation)
            )

            mstore(
                add(ptr, 0x32),
                hex"5a_f4_3d_3d_93_80_3e_6033_57_fd_5b_f3"
            )

            let counter := mload(data)
            let copyPtr := add(ptr, BOOTSTRAP_LENGTH)
            let dataPtr := add(data, ONE_WORD)

            for {} true {} {
                if lt(counter, ONE_WORD) {
                    break
                }

                mstore(copyPtr, mload(dataPtr))

                copyPtr := add(copyPtr, ONE_WORD)
                dataPtr := add(dataPtr, ONE_WORD)

                counter := sub(counter, ONE_WORD)
            }
                    
            let mask := shl(
                mul(0x8, sub(ONE_WORD, counter)), 
                not(0)
            )

            mstore(copyPtr, and(mload(dataPtr), mask))
            copyPtr := add(copyPtr, counter)
            mstore(copyPtr, shl(0xf0, extraLength))

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
    ) internal virtual returns (address payable instance) {
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
    /// @dev data cannot exceed 65535 bytes, since 2 bytes are used to store the data length
    /// @param implementation The implementation contract to clone
    /// @param salt The salt for create2
    /// @param data Encoded immutable args
    /// @return predicted The predicted address of the created clone
    /// @return exists Whether the clone already exists
    function predictDeterministicAddress(
        address implementation,
        bytes32 salt,
        bytes memory data
    ) internal view virtual returns (address predicted, bool exists) {
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
