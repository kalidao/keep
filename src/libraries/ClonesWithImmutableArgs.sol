// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

/// @notice Enables creating clone contracts with immutable arguments and CREATE2
/// @author Modified from wighawag, zefram.eth
/// (https://github.com/wighawag/clones-with-immutable-args/blob/master/src/ClonesWithImmutableArgs.sol)
/// @dev extended by will@0xsplits.xyz to add receive() without DELEGECALL & create2 support
/// (h/t WyseNynja https://github.com/wighawag/clones-with-immutable-args/issues/4)
library ClonesWithImmutableArgs {
    error Create2fail();

    /// @notice Creates a clone proxy of the implementation contract with immutable args
    /// @dev data cannot exceed 65535 bytes, since 2 bytes are used to store the data length
    /// @param implementation The implementation contract to clone
    /// @param data Encoded immutable args
    /// @return ptr The ptr to the clone's bytecode
    /// @return creationSize The size of the clone to be created
    function _cloneCreationCode(address implementation, bytes memory data)
        internal
        pure
        returns (uint256 ptr, uint256 creationSize)
    {
        // unrealistic for memory ptr or data length to exceed 256 bits
        unchecked {
            uint256 extraLength = data.length + 2; // +2 bytes for telling how much data there is appended to the call
            creationSize = 0x71 + extraLength;
            uint256 runSize = creationSize - 10;
            uint256 dataPtr;

            assembly {
                ptr := mload(0x40)

                // -------------------------------------------------------------------------------------------------------------
                // CREATION (10 bytes)
                // -------------------------------------------------------------------------------------------------------------

                // 61 runtime  | PUSH2 runtime (r)     | r                       | –
                mstore(
                    ptr,
                    0x6100000000000000000000000000000000000000000000000000000000000000
                )
                
                mstore(add(ptr, 0x01), shl(240, runSize)) // size of the contract running bytecode (16 bits)

                // creation size = 0a
                // 3d          | RETURNDATASIZE        | 0 r                     | –
                // 81          | DUP2                  | r 0 r                   | –
                // 60 creation | PUSH1 creation (c)    | c r 0 r                 | –
                // 3d          | RETURNDATASIZE        | 0 c r 0 r               | –
                // 39          | CODECOPY              | 0 r                     | [0-runSize): runtime code
                // f3          | RETURN                |                         | [0-runSize): runtime code

                // -------------------------------------------------------------------------------------------------------------
                // RUNTIME (103 bytes + extraLength)
                // -------------------------------------------------------------------------------------------------------------

                //     0x000     36       calldatasize      cds                  | -
                //     0x001     602f     push1 0x2f        0x2f cds             | -
                // ,=< 0x003     57       jumpi                                  | -
                // |   0x004     34       callvalue         cv                   | -
                // |   0x005     3d       returndatasize    0 cv                 | -
                // |   0x006     52       mstore                                 | [0, 0x20) = cv
                // |   0x007     7f245c.. push32 0x245c..   id                   | [0, 0x20) = cv
                // |   0x028     6020     push1 0x20        0x20 id              | [0, 0x20) = cv
                // |   0x02a     3d       returndatasize    0 0x20 id            | [0, 0x20) = cv
                // |   0x02b     a1       log1                                   | [0, 0x20) = cv
                // |   0x02c     3d       returndatasize    0                    | [0, 0x20) = cv
                // |   0x02d     3d       returndatasize    0 0                  | [0, 0x20) = cv
                // |   0x02e     f3       return
                // `-> 0x02f     5b       jumpdest

                // 3d          | RETURNDATASIZE        | 0                       | –
                // 3d          | RETURNDATASIZE        | 0 0                     | –
                // 3d          | RETURNDATASIZE        | 0 0 0                   | –
                // 3d          | RETURNDATASIZE        | 0 0 0 0                 | –
                // 36          | CALLDATASIZE          | cds 0 0 0 0             | –
                // 3d          | RETURNDATASIZE        | 0 cds 0 0 0 0           | –
                // 3d          | RETURNDATASIZE        | 0 0 cds 0 0 0 0         | –
                // 37          | CALLDATACOPY          | 0 0 0 0                 | [0, cds) = calldata
                // 61          | PUSH2 extra           | extra 0 0 0 0           | [0, cds) = calldata
                mstore(
                    add(ptr, 0x03),
                    0x3d81600a3d39f336602f57343d527f0000000000000000000000000000000000
                )
                
                mstore(
                    add(ptr, 0x12),
                    // = keccak256('ReceiveETH(uint256)')
                    0x9e4ac34f21c619cefc926c8bd93b54bf5a39c7ab2127a895af1cc0691d7e3dff
                )
                
                mstore(
                    add(ptr, 0x32),
                    0x60203da13d3df35b3d3d3d3d363d3d3761000000000000000000000000000000
                )
                
                mstore(add(ptr, 0x43), shl(240, extraLength))

                // 60 0x67     | PUSH1 0x67            | 0x67 extra 0 0 0 0      | [0, cds) = calldata // 0x67 (103) is runtime size - data
                // 36          | CALLDATASIZE          | cds 0x67 extra 0 0 0 0  | [0, cds) = calldata
                // 39          | CODECOPY              | 0 0 0 0                 | [0, cds) = calldata, [cds, cds+0x37) = extraData
                // 36          | CALLDATASIZE          | cds 0 0 0 0             | [0, cds) = calldata, [cds, cds+0x37) = extraData
                // 61 extra    | PUSH2 extra           | extra cds 0 0 0 0       | [0, cds) = calldata, [cds, cds+0x37) = extraData
                mstore(
                    add(ptr, 0x45),
                    0x6067363936610000000000000000000000000000000000000000000000000000
                )
                
                mstore(add(ptr, 0x4b), shl(240, extraLength))

                // 01          | ADD                   | cds+extra 0 0 0 0       | [0, cds) = calldata, [cds, cds+0x37) = extraData
                // 3d          | RETURNDATASIZE        | 0 cds 0 0 0 0           | [0, cds) = calldata, [cds, cds+0x37) = extraData
                // 73 addr     | PUSH20 0x123…         | addr 0 cds 0 0 0 0      | [0, cds) = calldata, [cds, cds+0x37) = extraData
                mstore(
                    add(ptr, 0x4d),
                    0x013d730000000000000000000000000000000000000000000000000000000000
                )
                
                mstore(add(ptr, 0x50), shl(0x60, implementation))

                // 5a          | GAS                   | gas addr 0 cds 0 0 0 0  | [0, cds) = calldata, [cds, cds+0x37) = extraData
                // f4          | DELEGATECALL          | success 0 0             | [0, cds) = calldata, [cds, cds+0x37) = extraData
                // 3d          | RETURNDATASIZE        | rds success 0 0         | [0, cds) = calldata, [cds, cds+0x37) = extraData
                // 3d          | RETURNDATASIZE        | rds rds success 0 0     | [0, cds) = calldata, [cds, cds+0x37) = extraData
                // 93          | SWAP4                 | 0 rds success 0 rds     | [0, cds) = calldata, [cds, cds+0x37) = extraData
                // 80          | DUP1                  | 0 0 rds success 0 rds   | [0, cds) = calldata, [cds, cds+0x37) = extraData
                // 3e          | RETURNDATACOPY        | success 0 rds           | [0, rds) = return data (there might be some irrelevant leftovers in memory [rds, cds+0x37) when rds < cds+0x37)
                // 60 0x65     | PUSH1 0x65            | 0x65 sucess 0 rds       | [0, rds) = return data
                // 57          | JUMPI                 | 0 rds                   | [0, rds) = return data
                // fd          | REVERT                | –                       | [0, rds) = return data
                // 5b          | JUMPDEST              | 0 rds                   | [0, rds) = return data
                // f3          | RETURN                | –                       | [0, rds) = return data
                mstore(
                    add(ptr, 0x64),
                    0x5af43d3d93803e606557fd5bf300000000000000000000000000000000000000
                )
            }

            // -------------------------------------------------------------------------------------------------------------
            // APPENDED DATA (Accessible from extcodecopy)
            // (but also send as appended data to the delegatecall)
            // -------------------------------------------------------------------------------------------------------------

            extraLength -= 2;
            uint256 counter = extraLength;
            uint256 copyPtr = ptr + 0x71;

            assembly {
                dataPtr := add(data, 32)
            }
            
            for ( ; counter >= 32; counter -= 32) {
                assembly {
                    mstore(copyPtr, mload(dataPtr))
                }

                copyPtr += 32;
                dataPtr += 32;
            }
            
            uint256 mask = ~(256**(32 - counter) - 1);

            assembly {
                mstore(copyPtr, and(mload(dataPtr), mask))
            }
            
            copyPtr += counter;

            assembly {
                mstore(copyPtr, shl(240, extraLength))
            }
        }
    }

    /// @notice Creates a clone proxy of the implementation contract with immutable args
    /// @dev data cannot exceed 65535 bytes, since 2 bytes are used to store the data length
    /// @param implementation The implementation contract to clone
    /// @param salt The salt for create2
    /// @param data Encoded immutable args
    /// @return instance The address of the created clone
    function _clone(
        address implementation,
        bytes32 salt,
        bytes memory data
    ) internal returns (address payable instance) {
        (uint256 creationPtr, uint256 creationSize) = _cloneCreationCode(
            implementation,
            data
        );

        assembly {
            instance := create2(0, creationPtr, creationSize, salt)
        }
        
        // if the create2 failed, the instance address won't be set
        if (instance == address(0)) {
            revert Create2fail();
        }
    }

    /// @notice Predicts the address where a deterministic clone of implementation will be deployed
    /// @dev data cannot exceed 65535 bytes, since 2 bytes are used to store the data length
    /// @param implementation The implementation contract to clone
    /// @param salt The salt for create2
    /// @param data Encoded immutable args
    /// @return predicted The predicted address of the created clone
    /// @return exists Whether the clone already exists
    function _predictDeterministicAddress(
        address implementation,
        bytes32 salt,
        bytes memory data
    ) internal view returns (address predicted, bool exists) {
        (uint256 creationPtr, uint256 creationSize) = _cloneCreationCode(
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
