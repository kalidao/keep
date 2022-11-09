// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Contract helper for ERC1155 safeTransferFrom.
abstract contract ERC1155STF {
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) public virtual;
}

/// @notice Contract helper for Keep token minting.
abstract contract KeepTokenMint {
    function balanceOf(address account, uint256 id)
        public
        view
        virtual
        returns (uint256);

    function mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) public virtual;
}

/// @notice ERC1155 interface to receive tokens.
/// @author Modified from Solbase (https://github.com/Sol-DAO/solbase/blob/main/src/tokens/ERC1155/ERC1155.sol)
abstract contract ERC1155TokenReceiver {
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) public payable virtual returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) public payable virtual returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }
}

/// @notice Contract helper for any EIP-2612, EIP-4494 or Dai-style token permit.
/// @author Solbase (https://github.com/Sol-DAO/solbase/blob/main/src/utils/Permit.sol)
abstract contract Permit {
    /// @dev ERC20.

    /// @notice Permit to spend tokens for EIP-2612 permit signatures.
    /// @param owner The address of the token holder.
    /// @param spender The address of the token permit holder.
    /// @param value The amount permitted to spend.
    /// @param deadline The unix timestamp before which permit must be spent.
    /// @param v Must produce valid secp256k1 signature from the `owner` along with `r` and `s`.
    /// @param r Must produce valid secp256k1 signature from the `owner` along with `v` and `s`.
    /// @param s Must produce valid secp256k1 signature from the `owner` along with `r` and `v`.
    /// @dev This permit will work for certain ERC721 supporting EIP-2612-style permits,
    /// such as Uniswap V3 position and Solbase NFTs.
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual;

    /// @notice Permit to spend tokens for permit signatures that have the `allowed` parameter.
    /// @param owner The address of the token holder.
    /// @param spender The address of the token permit holder.
    /// @param nonce The current nonce of the `owner`.
    /// @param deadline The unix timestamp before which permit must be spent.
    /// @param allowed If true, `spender` will be given permission to spend `owner`'s tokens.
    /// @param v Must produce valid secp256k1 signature from the `owner` along with `r` and `s`.
    /// @param r Must produce valid secp256k1 signature from the `owner` along with `v` and `s`.
    /// @param s Must produce valid secp256k1 signature from the `owner` along with `r` and `v`.
    function permit(
        address owner,
        address spender,
        uint256 nonce,
        uint256 deadline,
        bool allowed,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual;

    /// @dev ERC721.

    /// @notice Permit to spend specific NFT `tokenId` for EIP-2612-style permit signatures.
    /// @param spender The address of the token permit holder.
    /// @param tokenId The ID of the token that is being approved for permit.
    /// @param deadline The unix timestamp before which permit must be spent.
    /// @param v Must produce valid secp256k1 signature from the `owner` along with `r` and `s`.
    /// @param r Must produce valid secp256k1 signature from the `owner` along with `v` and `s`.
    /// @param s Must produce valid secp256k1 signature from the `owner` along with `r` and `v`.
    /// @dev Modified from Uniswap
    /// (https://github.com/Uniswap/v3-periphery/blob/main/contracts/interfaces/IERC721Permit.sol).
    function permit(
        address spender,
        uint256 tokenId,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual;

    /// @notice Permit to spend specific NFT `tokenId` for EIP-4494 permit signatures.
    /// @param spender The address of the token permit holder.
    /// @param tokenId The ID of the token that is being approved for permit.
    /// @param deadline The unix timestamp before which permit must be spent.
    /// @param sig A traditional or EIP-2098 signature.
    function permit(
        address spender,
        uint256 tokenId,
        uint256 deadline,
        bytes calldata sig
    ) public virtual;

    /// @dev ERC1155.

    /// @notice Permit to spend multitoken IDs for EIP-2612-style permit signatures.
    /// @param owner The address of the token holder.
    /// @param operator The address of the token permit holder.
    /// @param approved If true, `operator` will be given permission to spend `owner`'s tokens.
    /// @param deadline The unix timestamp before which permit must be spent.
    /// @param v Must produce valid secp256k1 signature from the `owner` along with `r` and `s`.
    /// @param r Must produce valid secp256k1 signature from the `owner` along with `v` and `s`.
    /// @param s Must produce valid secp256k1 signature from the `owner` along with `r` and `v`.
    function permit(
        address owner,
        address operator,
        bool approved,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual;
}

/// @notice Self helper for any EIP-2612, EIP-4494 or Dai-style token permit.
/// @author Solbase (https://github.com/Sol-DAO/solbase/blob/main/src/utils/SelfPermit.sol)
/// @author Modified from Uniswap (https://github.com/Uniswap/v3-periphery/blob/main/contracts/base/SelfPermit.sol)
/// @dev These functions are expected to be embedded in multicall to allow EOAs to approve a contract and call a function
/// that requires an approval in a single transaction.
abstract contract SelfPermit {
    /// @dev ERC20.

    /// @notice Permits this contract to spend a given EIP-2612 `token` from `msg.sender`.
    /// @dev The `owner` is always `msg.sender` and the `spender` is always `address(this)`.
    /// @param token The address of the asset spent.
    /// @param value The amount permitted to spend.
    /// @param deadline The unix timestamp before which permit must be spent.
    /// @param v Must produce valid secp256k1 signature from the `msg.sender` along with `r` and `s`.
    /// @param r Must produce valid secp256k1 signature from the `msg.sender` along with `v` and `s`.
    /// @param s Must produce valid secp256k1 signature from the `msg.sender` along with `r` and `v`.
    function selfPermit(
        Permit token,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual {
        token.permit(msg.sender, address(this), value, deadline, v, r, s);
    }

    /// @notice Permits this contract to spend a given Dai-style `token` from `msg.sender`.
    /// @dev The `owner` is always `msg.sender` and the `spender` is always `address(this)`.
    /// @param token The address of the asset spent.
    /// @param nonce The current nonce of the `owner`.
    /// @param deadline The unix timestamp before which permit must be spent.
    /// @param v Must produce valid secp256k1 signature from the `msg.sender` along with `r` and `s`.
    /// @param r Must produce valid secp256k1 signature from the `msg.sender` along with `v` and `s`.
    /// @param s Must produce valid secp256k1 signature from the `msg.sender` along with `r` and `v`.
    function selfPermitAllowed(
        Permit token,
        uint256 nonce,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual {
        token.permit(msg.sender, address(this), nonce, deadline, true, v, r, s);
    }

    /// @dev ERC721.

    /// @notice Permits this contract to spend a given EIP-2612-style NFT `tokenID` from `msg.sender`.
    /// @dev The `spender` is always `address(this)`.
    /// @param token The address of the asset spent.
    /// @param tokenId The ID of the token that is being approved for permit.
    /// @param deadline The unix timestamp before which permit must be spent.
    /// @param v Must produce valid secp256k1 signature from the `msg.sender` along with `r` and `s`.
    /// @param r Must produce valid secp256k1 signature from the `msg.sender` along with `v` and `s`.
    /// @param s Must produce valid secp256k1 signature from the `msg.sender` along with `r` and `v`.
    function selfPermit721(
        Permit token,
        uint256 tokenId,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual {
        token.permit(address(this), tokenId, deadline, v, r, s);
    }

    /// @notice Permits this contract to spend a given EIP-4494 NFT `tokenID`.
    /// @dev The `spender` is always `address(this)`.
    /// @param token The address of the asset spent.
    /// @param tokenId The ID of the token that is being approved for permit.
    /// @param deadline The unix timestamp before which permit must be spent.
    /// @param sig A traditional or EIP-2098 signature.
    function selfPermit721(
        Permit token,
        uint256 tokenId,
        uint256 deadline,
        bytes calldata sig
    ) public virtual {
        token.permit(address(this), tokenId, deadline, sig);
    }

    /// @dev ERC1155.

    /// @notice Permits this contract to spend a given EIP-2612-style multitoken.
    /// @dev The `owner` is always `msg.sender` and the `operator` is always `address(this)`.
    /// @param token The address of the asset spent.
    /// @param deadline The unix timestamp before which permit must be spent.
    /// @param v Must produce valid secp256k1 signature from the `msg.sender` along with `r` and `s`.
    /// @param r Must produce valid secp256k1 signature from the `msg.sender` along with `v` and `s`.
    /// @param s Must produce valid secp256k1 signature from the `msg.sender` along with `r` and `v`.
    function selfPermit1155(
        Permit token,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual {
        token.permit(msg.sender, address(this), true, deadline, v, r, s);
    }
}

/// @notice Gas-optimized reentrancy protection for smart contracts.
/// @author Solbase (https://github.com/Sol-DAO/solbase/blob/main/src/utils/ReentrancyGuard.sol)
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

/// @notice Contract that enables a single call to call multiple methods on itself.
/// @author Solbase (https://github.com/Sol-DAO/solbase/blob/main/src/utils/SafeMulticallable.sol)
/// @author Modified from Solady (https://github.com/vectorized/solady/blob/main/src/utils/Multicallable.sol)
/// @dev This version of Multicallable removes `payable` `multicall()` against risk of double-spend vulnerabilities.
abstract contract SafeMulticallable {
    /// @dev Apply `DELEGATECALL` with the current contract to each calldata in `data`,
    /// and store the `abi.encode` formatted results of each `DELEGATECALL` into `results`.
    /// If any of the `DELEGATECALL`s reverts, the entire transaction is reverted,
    /// and the error is bubbled up.
    function multicall(bytes[] calldata data)
        public
        virtual
        returns (bytes[] memory results)
    {
        assembly {
            if data.length {
                results := mload(0x40) // Point `results` to start of free memory.
                mstore(results, data.length) // Store `data.length` into `results`.
                results := add(results, 0x20)

                // `shl` 5 is equivalent to multiplying by 0x20.
                let end := shl(5, data.length)
                // Copy the offsets from calldata into memory.
                calldatacopy(results, data.offset, end)
                // Pointer to the top of the memory (i.e. start of the free memory).
                let memPtr := add(results, end)
                end := add(results, end)

                // prettier-ignore
                for {} 1 {} {
                    // The offset of the current bytes in the calldata.
                    let o := add(data.offset, mload(results))
                    // Copy the current bytes from calldata to the memory.
                    calldatacopy(
                        memPtr,
                        add(o, 0x20), // The offset of the current bytes' bytes.
                        calldataload(o) // The length of the current bytes.
                    )
                    if iszero(delegatecall(gas(), address(), memPtr, calldataload(o), 0x00, 0x00)) {
                        // Bubble up the revert if the delegatecall reverts.
                        returndatacopy(0x00, 0x00, returndatasize())
                        revert(0x00, returndatasize())
                    }
                    // Append the current `memPtr` into `results`.
                    mstore(results, memPtr)
                    results := add(results, 0x20)
                    // Append the `returndatasize()`, and the return data.
                    mstore(memPtr, returndatasize())
                    returndatacopy(add(memPtr, 0x20), 0x00, returndatasize())
                    // Advance the `memPtr` by `returndatasize() + 0x20`,
                    // rounded up to the next multiple of 32.
                    memPtr := and(add(add(memPtr, returndatasize()), 0x3f), 0xffffffffffffffe0)
                    // prettier-ignore
                    if iszero(lt(results, end)) { break }
                }
                // Restore `results` and allocate memory for it.
                results := mload(0x40)
                mstore(0x40, memPtr)
            }
        }
    }
}

/// @notice Safe ETH and ERC20 free function transfer collection that gracefully handles missing return values.
/// @author Solbase (https://github.com/Sol-DAO/solbase/blob/main/src/utils/SafeTransfer.sol)
/// @author Modified from Zolidity (https://github.com/z0r0z/zolidity/blob/main/src/utils/SafeTransfer.sol)

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

/// @title Tribute Router
/// @notice Moloch-style Keep tribute escrow router in ETH and any token (ERC20/721/1155).
/// @dev This extension is enabled while it holds a Keep mint ID key.

enum Standard {
    ETH,
    ERC20,
    ERC721,
    ERC1155
}

struct Tribute {
    address from;
    address to;
    uint96 forId;
    address asset;
    Standard std;
    uint88 tokenId;
    uint112 amount;
    uint112 forAmount;
    uint32 deadline;
}

/// @author z0r0z.eth
contract TributeRouter is
    ERC1155TokenReceiver,
    SelfPermit,
    ReentrancyGuard,
    SafeMulticallable
{
    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event TributeMade(
        uint256 indexed id,
        address indexed from,
        address indexed to,
        address asset,
        Standard std,
        uint88 tokenId,
        uint112 amount,
        uint96 forId,
        uint112 forAmount,
        uint32 deadline
    );

    event TributeReleased(
        address indexed operator,
        uint256 indexed id,
        bool approve
    );

    /// -----------------------------------------------------------------------
    /// Custom Errors
    /// -----------------------------------------------------------------------

    error InvalidETHTribute();

    error AlreadyReleased();

    error Unauthorized();

    error DeadlinePending();

    /// -----------------------------------------------------------------------
    /// Tribute Storage
    /// -----------------------------------------------------------------------

    uint256 internal constant MINT_KEY = uint32(KeepTokenMint.mint.selector);

    uint256 public count;

    mapping(uint256 => Tribute) public tributes;

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    /// @dev Gas optimization.
    constructor() payable {}

    /// -----------------------------------------------------------------------
    /// Tribute Logic
    /// -----------------------------------------------------------------------

    /// @notice Escrow for a Keep token mint.
    /// @param to The Keep to make tribute to.
    /// @param asset The token address for tribute.
    /// @param std The EIP interface for tribute `asset`.
    /// @param tokenId The ID of `asset` to make tribute in.
    /// @param amount The amount of `asset` to make tribute in.
    /// @param forId The ERC1155 Keep token ID to make tribute for.
    /// @param forAmount The ERC1155 Keep token ID amount to make tribute for.
    /// @param deadline The unix time at which the escrowed tribute will expire.
    /// @return id The Keep escrow ID assigned incrementally for each escrow tribute.
    /// @dev The `tokenId` will be used where tribute `asset` follows ERC721 or ERC1155.
    function makeTribute(
        address to,
        address asset,
        Standard std,
        uint88 tokenId,
        uint112 amount,
        uint96 forId,
        uint112 forAmount,
        uint32 deadline
    ) public payable virtual nonReentrant returns (uint256 id) {
        // Unchecked because the only math done is incrementing
        // count which cannot realistically overflow.
        unchecked {
            id = count++;

            // Store packed variables.
            tributes[id] = Tribute({
                from: msg.sender,
                to: to,
                forId: forId,
                asset: asset,
                std: std,
                tokenId: tokenId,
                amount: amount,
                forAmount: forAmount,
                deadline: deadline
            });
        }

        // If user attaches ETH, handle as tribute.
        // Otherwise, token transfer performed.
        if (msg.value != 0) {
            if (msg.value != amount || std != Standard.ETH)
                revert InvalidETHTribute();
        } else if (std == Standard.ERC20) {
            safeTransferFrom(asset, msg.sender, address(this), amount);
        } else if (std == Standard.ERC721) {
            safeTransferFrom(asset, msg.sender, address(this), tokenId);
        } else if (std != Standard.ETH) {
            ERC1155STF(asset).safeTransferFrom(
                msg.sender,
                address(this),
                tokenId,
                amount,
                ""
            );
        }

        emit TributeMade(
            id, // Tribute escrow ID.
            msg.sender, // Tribute proposer.
            to,
            asset,
            std,
            tokenId,
            amount,
            forId,
            forAmount,
            deadline
        );
    }

    /// @notice Escrow release for a Keep token mint.
    /// @param id The escrow ID to activate tribute release for.
    /// @param approve If `true`, escrow will release to Keep for mint.
    /// If `false`, tribute will be returned back to the tribute proposer.
    /// @dev Calls are permissioned to the Keep itself or mint ID key holder.
    function releaseTribute(uint256 id, bool approve)
        public
        payable
        virtual
        nonReentrant
    {
        // Fetch tribute details from storage.
        Tribute storage trib = tributes[id];

        // Ensure no replay of tribute escrow.
        if (trib.from == address(0)) revert AlreadyReleased();

        // Check permissions for tribute release.
        if (msg.sender != trib.to)
            if (KeepTokenMint(trib.to).balanceOf(msg.sender, MINT_KEY) == 0)
                revert Unauthorized();

        // Branch release and minting on approval,
        // as well as on whether asset is ETH or token.
        if (approve) {
            if (trib.std == Standard.ETH) safeTransferETH(trib.to, trib.amount);
            else if (trib.std == Standard.ERC20)
                safeTransfer(trib.asset, trib.to, trib.amount);
            else if (trib.std == Standard.ERC721)
                safeTransferFrom(
                    trib.asset,
                    address(this),
                    trib.to,
                    trib.tokenId
                );
            else
                ERC1155STF(trib.asset).safeTransferFrom(
                    address(this),
                    trib.to,
                    trib.tokenId,
                    trib.amount,
                    ""
                );

            KeepTokenMint(trib.to).mint(
                trib.from,
                trib.forId,
                trib.forAmount,
                ""
            );
        } else {
            if (trib.std == Standard.ETH)
                safeTransferETH(trib.from, trib.amount);
            else if (trib.std == Standard.ERC20)
                safeTransfer(trib.asset, trib.from, trib.amount);
            else if (trib.std == Standard.ERC721)
                safeTransferFrom(
                    trib.asset,
                    address(this),
                    trib.from,
                    trib.tokenId
                );
            else
                ERC1155STF(trib.asset).safeTransferFrom(
                    address(this),
                    trib.from,
                    trib.tokenId,
                    trib.amount,
                    ""
                );
        }

        // Delete tribute escrow from storage so it can't be replayed.
        delete tributes[id];

        emit TributeReleased(msg.sender, id, approve);
    }

    /// @notice Timed depositor escrow release.
    /// @param id The escrow ID to activate tribute release for.
    /// @dev Deadline of zero effectively is strings-attached deposit.
    /// Otherwise, depositors might demonstrate greater faith in tribute
    /// by setting deadline timer. This can entertain time-based tokenomics.
    function withdrawTribute(uint256 id) public payable virtual nonReentrant {
        // Fetch tribute details from storage.
        Tribute storage trib = tributes[id];

        // Ensure no replay of tribute escrow.
        if (trib.from == address(0)) revert AlreadyReleased();

        // Check permission for tribute release.
        if (msg.sender != trib.from) revert Unauthorized();

        // Check deadline for tribute release.
        if (block.timestamp <= trib.deadline) revert DeadlinePending();

        if (trib.std == Standard.ETH) safeTransferETH(trib.from, trib.amount);
        else if (trib.std == Standard.ERC20)
            safeTransfer(trib.asset, trib.from, trib.amount);
        else if (trib.std == Standard.ERC721)
            safeTransferFrom(
                trib.asset,
                address(this),
                trib.from,
                trib.tokenId
            );
        else
            ERC1155STF(trib.asset).safeTransferFrom(
                address(this),
                trib.from,
                trib.tokenId,
                trib.amount,
                ""
            );

        // Delete tribute escrow from storage so it can't be replayed.
        delete tributes[id];

        emit TributeReleased(msg.sender, id, false);
    }
}
