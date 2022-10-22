// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

/// @dev The ETH transfer has failed.
error ETHTransferFailed();

/// @dev Sends `amount` (in wei) ETH to `to`.
/// Reverts upon failure.
function safeTransferETH(address to, uint256 amount) {
    assembly {
        // Transfer the ETH and check if it succeeded or not.
        if iszero(call(gas(), to, amount, 0, 0, 0, 0)) {
            // Store the function selector of `ETHTransferFailed()`.
            mstore(0x00, 0xb12d13eb)
            // Revert with (offset, size).
            revert(0x1c, 0x04)
        }
    }
}

/// @dev The ERC20 `transfer` has failed.
error TransferFailed();

/// @dev Sends `amount` of ERC20 `token` from the current contract to `to`.
/// Reverts upon failure.
function safeTransfer(
    address token,
    address to,
    uint256 amount
) {
    assembly {
        // We'll write our calldata to this slot below, but restore it later.
        let memPointer := mload(0x40)

        // Write the abi-encoded calldata into memory, beginning with the function selector.
        mstore(0x00, 0xa9059cbb)
        mstore(0x20, to) // Append the "to" argument.
        mstore(0x40, amount) // Append the "amount" argument.

        if iszero(
            and(
                // Set success to whether the call reverted, if not we check it either
                // returned exactly 1 (can't just be non-zero data), or had no return data.
                or(eq(mload(0x00), 1), iszero(returndatasize())),
                // We use 0x44 because that's the total length of our calldata (0x04 + 0x20 * 2)
                // Counterintuitively, this call() must be positioned after the or() in the
                // surrounding and() because and() evaluates its arguments from right to left.
                call(gas(), token, 0, 0x1c, 0x44, 0x00, 0x20)
            )
        ) {
            // Store the function selector of `TransferFailed()`.
            mstore(0x00, 0x90b8ec18)
            // Revert with (offset, size).
            revert(0x1c, 0x04)
        }

        mstore(0x40, memPointer) // Restore the memPointer.
    }
}

/// @dev The ERC20 `transferFrom` has failed.
error TransferFromFailed();

/// @dev Sends `amount` of ERC20 `token` from `from` to `to`.
/// Reverts upon failure.
///
/// The `from` account must have at least `amount` approved for
/// the current contract to manage.
function safeTransferFrom(
    address token,
    address from,
    address to,
    uint256 amount
) {
    assembly {
        // We'll write our calldata to this slot below, but restore it later.
        let memPointer := mload(0x40)

        // Write the abi-encoded calldata into memory, beginning with the function selector.
        mstore(0x00, 0x23b872dd)
        mstore(0x20, from) // Append the "from" argument.
        mstore(0x40, to) // Append the "to" argument.
        mstore(0x60, amount) // Append the "amount" argument.

        if iszero(
            and(
                // Set success to whether the call reverted, if not we check it either
                // returned exactly 1 (can't just be non-zero data), or had no return data.
                or(eq(mload(0x00), 1), iszero(returndatasize())),
                // We use 0x64 because that's the total length of our calldata (0x04 + 0x20 * 3)
                // Counterintuitively, this call() must be positioned after the or() in the
                // surrounding and() because and() evaluates its arguments from right to left.
                call(gas(), token, 0, 0x1c, 0x64, 0x00, 0x20)
            )
        ) {
            // Store the function selector of `TransferFromFailed()`.
            mstore(0x00, 0x7939f424)
            // Revert with (offset, size).
            revert(0x1c, 0x04)
        }

        mstore(0x60, 0) // Restore the zero slot to zero.
        mstore(0x40, memPointer) // Restore the memPointer.
    }
}

/// @dev Interface for Keep token minting.
interface KeepTokenMint {
    function balanceOf(address account, uint256 id) external view returns (uint256);

    function mint(
        address to,
        uint256 id, 
        uint256 amount, 
        bytes calldata data
    ) external;
}

/// @notice Gas-optimized reentrancy protection for smart contracts.
/// @author SolDAO (https://github.com/Sol-DAO/solbase/blob/main/src/utils/ReentrancyGuard.sol)
abstract contract ReentrancyGuard {
    error Reentrancy();

    uint256 private locked = 1;

    modifier nonReentrant() virtual {
        if (locked == 2) revert Reentrancy();

        locked = 2;

        _;

        locked = 1;
    }
}

/// @dev Tribute is initialized by Keep by giving it a mint ID key.
contract KeepTributeRouter is ReentrancyGuard {
    event MakeTribute(
        uint256 id,
        address from,
        address to,
        address asset,
        uint256 tribute,
        uint256 forId,
        uint256 forAmount
    );

    event ReleaseTribute(
        address operator,
        uint256 id,
        bool approve
    );

    uint256 public currentId;

    mapping(uint256 => Tribute) public tributes;

    error InsufficientETH();

    error Unauthorized();

    struct Tribute {
        address from;
        address to;
        address asset;
        uint96 tribute;
        uint96 forId;
        uint96 forAmount;
    }

    function makeTribute(
        address to, 
        address asset, 
        uint256 tribute,
        uint256 forId,
        uint256 forAmount
    ) public payable nonReentrant virtual returns (uint256 id) {
        unchecked {
            id = currentId++;

            tributes[id] = Tribute({
                from: msg.sender,
                to: to,
                asset: asset,
                tribute: uint96(tribute),
                forId: uint96(forId),
                forAmount: uint96(forAmount)
            });
        }

        if (asset == address(0) && msg.value != tribute) revert InsufficientETH();
        else safeTransferFrom(asset, msg.sender, address(this), tribute);

        emit MakeTribute(
            id,
            msg.sender,
            to,
            asset,
            tribute,
            forId,
            forAmount
        );
    }

    function releaseTribute(uint256 id, bool approve) public payable nonReentrant virtual {
        Tribute storage trib = tributes[id];

        if (KeepTokenMint(trib.to).balanceOf(msg.sender, uint32(KeepTokenMint.balanceOf.selector)) == 0)
            revert Unauthorized();
        
        if (approve) {
            trib.asset == address(0) ? safeTransferETH(trib.to, trib.tribute)
            : safeTransfer(trib.asset, trib.to, trib.tribute);

            KeepTokenMint(trib.to).mint(trib.to, trib.forId, trib.forAmount, "");
        } else {
            trib.asset == address(0) ? safeTransferETH(trib.from, trib.tribute)
            : safeTransfer(trib.asset, trib.from, trib.tribute);
        }

        emit ReleaseTribute(
            msg.sender,
            id,
            approve
        );
    }
}
