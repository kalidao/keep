// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

/// @notice Safe ERC-20 transfer library that gracefully handles missing return values
/// @author Modified from Solady (https://github.com/Vectorized/solady/blob/main/src/utils/SafeTransferLib.sol)
library SafeTransferLib {
    error TransferFromFailed();
    
    function safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 amount
    ) internal {
        assembly {
            // we'll write our calldata to this slot below, but restore it later
            let memPointer := mload(0x40)

            // write the abi-encoded calldata into memory, beginning with the function selector
            mstore(0x00, 0x23b872dd)
            mstore(0x20, from) // append the "from" argument
            mstore(0x40, to) // append the "to" argument
            mstore(0x60, amount) // append the "amount" argument

            if iszero(
                and(
                    // set success to whether the call reverted, if not we check it either
                    // returned exactly 1 (can't just be non-zero data), or had no return data
                    or(eq(mload(0x00), 1), iszero(returndatasize())),
                    // we use 0x64 because that's the total length of our calldata (0x04 + 0x20 * 3)
                    // - counterintuitively, this call() must be positioned after the or() in the
                    // surrounding and() because and() evaluates its arguments from right to left
                    call(gas(), token, 0, 0x1c, 0x64, 0x00, 0x20)
                )
            ) {
                // store the function selector of `TransferFromFailed()`
                mstore(0x00, 0x7939f424)
                // revert with (offset, size)
                revert(0x1c, 0x04)
            }

            mstore(0x60, 0) // restore the zero slot to zero
            mstore(0x40, memPointer) // restore the memPointer
        }
    }
}
