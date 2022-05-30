// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

/// @notice Safe ETH and ERC-20 transfer library that gracefully handles missing return values
/// @author Modified from Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/utils/SafeTransferLib.sol)
/// License-Identifier: AGPL-3.0-only
library SafeTransferLib {
    function _safeTransferETH(address to, uint256 amount) internal {
        assembly {
            // transfer the ETH and store if it succeeded or not
            let success := call(gas(), to, amount, 0, 0, 0, 0)

            if iszero(success) {
                mstore(0x64, 0x08c379a0) // function selector of the error method, offseted
                mstore(0x84, 0x20) // offset of the error string
                mstore(0xc3, '\x13ETH_TRANSFER_FAILED') // error string's length and bytes
                revert(0x80, 0x64) // revert with (offset, size)
            }
        }
    }

    function _safeTransfer(
        address token,
        address to,
        uint256 amount
    ) internal {
        assembly {
            // we'll write our calldata to this slot below, but restore it later
            let memPointer := mload(0x40)
            // write the abi-encoded calldata into memory, beginning with the function selector
            mstore(0, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
            mstore(4, to) // append the 'to' argument
            mstore(36, amount) // append the 'amount' argument

            let success := and(
                // set success to whether the call reverted, if not we check it either
                // returned exactly 1 (can't just be non-zero data), or had no return data
                or(and(eq(mload(0), 1), gt(returndatasize(), 31)), iszero(returndatasize())),
                // we use 68 because that's the total length of our calldata (4 + 32 * 2)
                // - counterintuitively, this call() must be positioned after the or() in the
                // surrounding and() because and() evaluates its arguments from right to left
                call(gas(), token, 0, 0, 68, 0, 32)
            )
            
            if iszero(success) {
                mstore(0x64, 0x08c379a0) // function selector of the error method
                mstore(0x84, 0x20) // offset of the error string
                mstore(0xc3, '\x0fTRANSFER_FAILED') // error string's length and bytes
                revert(0x80, 0x64) // revert with (offset, size)
            }

            mstore(0x60, 0) // restore the zero slot to zero
            mstore(0x40, memPointer) // restore the memPointer
        }
    }
}
