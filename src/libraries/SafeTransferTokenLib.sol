// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity >=0.8.4;

/// @notice Safe ERC20 transfer library that gracefully handles missing return values
/// @author Modified from Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/utils/SafeTransferLib.sol)
/// License-Identifier: AGPL-3.0-only
/// @dev Use with caution! Some functions in this library knowingly create dirty bits at the destination of the free memory pointer
/// @dev Note that none of the functions in this library check that a token has code at all! That responsibility is delegated to the caller
library SafeTransferTokenLib {
    error TransferFailed();

    function _safeTransfer(
        address token,
        address to,
        uint256 amount
    ) internal {
        bool success;

        assembly {
            // get a pointer to some free memory
            let freeMemoryPointer := mload(0x40)

            // write the abi-encoded calldata into memory, beginning with the function selector
            mstore(freeMemoryPointer, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
            mstore(add(freeMemoryPointer, 4), to) // mask and append the "to" argument
            mstore(add(freeMemoryPointer, 36), amount) // append the "amount" argument

            // fill up the scratch space so it's easy to tell if the call returns <32 bytes
            mstore(0, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)

            // call the token and store if it succeeded or not
            // we use 68 because the calldata length is 4 + 32 * 2
            // we'll copy up to 32 bytes of return data into the scratch space,
            // if it returns <32 bytes at least a portion of the junk will remain
            success := call(gas(), token, 0, freeMemoryPointer, 68, 0, 32)

            // set success to whether the call returned 1, except if it
            // had no return data, in which case we assume it succeeded,
            // or if it reverted, in which case we multiply everything by
            // 0, setting success to zero which will decode as false below
            success := mul(add(iszero(returndatasize()), eq(mload(0), 1)), success)
        }

        if (!success) revert TransferFailed();
    }
}
