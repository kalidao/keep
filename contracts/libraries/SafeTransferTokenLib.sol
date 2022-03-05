// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity >=0.8.4;

/// @notice Safe ERC20 transfer library that gracefully handles missing return values
/// @author Modified from Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/utils/SafeTransferLib.sol)
/// License-Identifier: AGPL-3.0-only
library SafeTransferTokenLib {
    error TransferFailed();

    function _safeTransfer(
        address token,
        address to,
        uint256 amount
    ) internal {
        bool callStatus;
        assembly {
            // get a pointer to some free memory
            let freeMemoryPointer := mload(0x40)
            // write the abi-encoded calldata to memory piece by piece:
            mstore(freeMemoryPointer, 0xa9059cbb00000000000000000000000000000000000000000000000000000000) // begin with the function selector
            mstore(add(freeMemoryPointer, 4), and(to, 0xffffffffffffffffffffffffffffffffffffffff)) // mask and append the "to" argument
            mstore(add(freeMemoryPointer, 36), amount) // finally append the "amount" argument - no mask as it's a full 32 byte value
            // call the token and store if it succeeded or not
            // we use 68 because the calldata length is 4 + 32 * 2
            callStatus := call(gas(), token, 0, freeMemoryPointer, 68, 0, 0)
        }
        if (!_didLastOptionalReturnCallSucceed(callStatus)) revert TransferFailed();
    }

    function _didLastOptionalReturnCallSucceed(bool callStatus) private pure returns (bool success) {
        assembly {
            // if the call reverted:
            if iszero(callStatus) {
                // copy the revert message into memory
                returndatacopy(0, 0, returndatasize())

                // revert with the same message.
                revert(0, returndatasize())
            }

            switch returndatasize()
            case 32 {
                // copy the return data into memory
                returndatacopy(0, 0, returndatasize())

                // set success to whether it returned true
                success := iszero(iszero(mload(0)))
            }
            case 0 {
                // there was no return data
                success := 1
            }
            default {
                // it returned some malformed output
                success := 0
            }
        }
    }
}
