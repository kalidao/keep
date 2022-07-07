// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

/// @notice Safe ERC-20 transfer library that gracefully handles missing return values
/// @author Modified from Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/utils/SafeTransferLib.sol)
/// @dev Caution! This library won't check that a token has code, responsibility is delegated to the caller
library SafeTransferLib {
    function _safeTransferFrom(
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
                mstore(0x00, hex"08c379a0") // function selector of the error method
                mstore(0x04, 0x20) // offset of the error string
                mstore(0x24, 20) // length of the error string
                mstore(0x44, "TRANSFER_FROM_FAILED") // the error string
                revert(0x00, 0x64) // revert with (offset, size)
            }

            mstore(0x60, 0) // restore the zero slot to zero
            mstore(0x40, memPointer) // restore the memPointer
        }
    }
}
