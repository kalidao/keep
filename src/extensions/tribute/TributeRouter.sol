// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {ERC1155STF} from "@kali/utils/ERC1155STF.sol";
import {KeepTokenMint} from "./utils/KeepTokenMint.sol";
import {ERC1155TokenReceiver} from "../../KeepToken.sol";
import {SelfPermit} from "@solbase/src/utils/SelfPermit.sol";
import {ReentrancyGuard} from "@solbase/src/utils/ReentrancyGuard.sol";
import {SafeMulticallable} from "@solbase/src/utils/SafeMulticallable.sol";
import {safeTransferETH, safeTransfer, safeTransferFrom} from "@solbase/src/utils/SafeTransfer.sol";

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

    error InvalidSig();

    /// -----------------------------------------------------------------------
    /// Tribute Storage
    /// -----------------------------------------------------------------------

    uint256 internal constant MINT_KEY = uint32(KeepTokenMint.mint.selector);

    uint256 public count;

    mapping(uint256 => Tribute) public tributes;

    /// -----------------------------------------------------------------------
    /// EIP-712 Storage/Logic
    /// -----------------------------------------------------------------------

    uint256 internal immutable INITIAL_CHAIN_ID;

    bytes32 internal immutable INITIAL_DOMAIN_SEPARATOR;

    bytes32 internal constant MALLEABILITY_THRESHOLD =
        0x7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0;

    mapping(address => uint256) public nonces;

    function DOMAIN_SEPARATOR() public view virtual returns (bytes32) {
        return
            block.chainid == INITIAL_CHAIN_ID
                ? INITIAL_DOMAIN_SEPARATOR
                : _computeDomainSeparator();
    }

    function _computeDomainSeparator() internal view virtual returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    keccak256(
                        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                    ),
                    keccak256(bytes("Tribute Router")),
                    keccak256("1"),
                    block.chainid,
                    address(this)
                )
            );
    }

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor() payable {
        INITIAL_CHAIN_ID = block.chainid;
        INITIAL_DOMAIN_SEPARATOR = _computeDomainSeparator();
    }

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

        // Check permission for tribute release.
        if (msg.sender != trib.from) revert Unauthorized();

        // Check deadline for tribute release.
        if (block.timestamp <= trib.deadline) revert DeadlinePending();

        if (trib.std == Standard.ETH) safeTransferETH(msg.sender, trib.amount);
        else if (trib.std == Standard.ERC20)
            safeTransfer(trib.asset, msg.sender, trib.amount);
        else if (trib.std == Standard.ERC721)
            safeTransferFrom(
                trib.asset,
                address(this),
                msg.sender,
                trib.tokenId
            );
        else
            ERC1155STF(trib.asset).safeTransferFrom(
                address(this),
                msg.sender,
                trib.tokenId,
                trib.amount,
                ""
            );

        // Delete tribute escrow from storage so it can't be replayed.
        delete tributes[id];

        emit TributeReleased(msg.sender, id, false);
    }

    /// -----------------------------------------------------------------------
    /// Tribute Signature Logic
    /// -----------------------------------------------------------------------

    /// @notice Escrow for a Keep token mint.
    /// @param from The maker of Keep tribute.
    /// @param to The Keep to make tribute to.
    /// @param asset The token address for tribute.
    /// @param std The EIP interface for tribute `asset`.
    /// @param tokenId The ID of `asset` to make tribute in.
    /// @param amount The amount of `asset` to make tribute in.
    /// @param forId The ERC1155 Keep token ID to make tribute for.
    /// @param forAmount The ERC1155 Keep token ID amount to make tribute for.
    /// @param deadline The unix time at which the escrowed tribute will expire.
    /// @param v Must produce valid secp256k1 signature from the `owner` along with `r` and `s`.
    /// @param r Must produce valid secp256k1 signature from the `owner` along with `v` and `s`.
    /// @param s Must produce valid secp256k1 signature from the `owner` along with `r` and `v`.
    /// @return id The Keep escrow ID assigned incrementally for each escrow tribute.
    /// @dev The `tokenId` will be used where tribute `asset` follows ERC721 or ERC1155.
    function makeTributeBySig(
        address from,
        address to,
        address asset,
        Standard std,
        uint88 tokenId,
        uint112 amount,
        uint96 forId,
        uint112 forAmount,
        uint32 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public payable virtual nonReentrant returns (uint256 id) {
        // Unchecked because the only math done is incrementing
        // the maker's nonce which cannot realistically overflow.
        unchecked {
            bytes32 hash = keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            keccak256(
                                "Tribute(address from,address to,address asset,Standard std,uint88 tokenId,uint112 amount,uint96 forId,uint112 forAmount,uint32 deadline)"
                            ),
                            from,
                            to,
                            asset,
                            std,
                            tokenId,
                            amount,
                            forId,
                            forAmount,
                            deadline,
                            nonces[from]++
                        )
                    )
                )
            );

            // Check signature recovery.
            _recoverSig(hash, from, v, r, s);
        }

        // Unchecked because the only math done is incrementing
        // count which cannot realistically overflow.
        unchecked {
            id = count++;

            // Store packed variables.
            tributes[id] = Tribute({
                from: from,
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
            safeTransferFrom(asset, from, address(this), amount);
        } else if (std == Standard.ERC721) {
            safeTransferFrom(asset, from, address(this), tokenId);
        } else if (std != Standard.ETH) {
            ERC1155STF(asset).safeTransferFrom(
                from,
                address(this),
                tokenId,
                amount,
                ""
            );
        }

        emit TributeMade(
            id, // Tribute escrow ID.
            from, // Tribute proposer.
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
    /// @param user The account managing Keep tribute release.
    /// @param id The escrow ID to activate tribute release for.
    /// @param approve If `true`, escrow will release to Keep for mint.
    /// If `false`, tribute will be returned back to the tribute proposer.
    /// @param v Must produce valid secp256k1 signature from the `owner` along with `r` and `s`.
    /// @param r Must produce valid secp256k1 signature from the `owner` along with `v` and `s`.
    /// @param s Must produce valid secp256k1 signature from the `owner` along with `r` and `v`.
    function releaseTributeBySig(
        address user,
        uint256 id,
        bool approve,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public payable virtual nonReentrant {
        // Fetch tribute details from storage.
        Tribute storage trib = tributes[id];

        // Ensure no replay of tribute escrow.
        if (trib.from == address(0)) revert AlreadyReleased();

        // Unchecked because the only math done is incrementing
        // the user's nonce which cannot realistically overflow.
        unchecked {
            bytes32 hash = keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            keccak256("Release(uint256 id,bool approve)"),
                            id,
                            approve,
                            nonces[user]++
                        )
                    )
                )
            );

            // Check signature recovery.
            _recoverSig(hash, user, v, r, s);
        }

        // Check permissions for tribute release.
        if (user != trib.to)
            if (KeepTokenMint(trib.to).balanceOf(user, MINT_KEY) == 0)
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

        emit TributeReleased(user, id, approve);
    }

    /// @notice Timed depositor escrow release.
    /// @param user The account managing Keep tribute withdraw.
    /// @param id The escrow ID to activate tribute release for.
    /// @param v Must produce valid secp256k1 signature from the `owner` along with `r` and `s`.
    /// @param r Must produce valid secp256k1 signature from the `owner` along with `v` and `s`.
    /// @param s Must produce valid secp256k1 signature from the `owner` along with `r` and `v`.
    function withdrawTributeBySig(
        address user,
        uint256 id,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public payable virtual nonReentrant {
        // Fetch tribute details from storage.
        Tribute storage trib = tributes[id];

        // Unchecked because the only math done is incrementing
        // the user's nonce which cannot realistically overflow.
        unchecked {
            bytes32 hash = keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            keccak256("Withdraw(uint256 id)"),
                            id,
                            nonces[user]++
                        )
                    )
                )
            );

            // Check signature recovery.
            _recoverSig(hash, user, v, r, s);
        }

        // Check permission for tribute release.
        if (user != trib.from) revert Unauthorized();

        // Check deadline for tribute release.
        if (block.timestamp <= trib.deadline) revert DeadlinePending();

        if (trib.std == Standard.ETH) safeTransferETH(user, trib.amount);
        else if (trib.std == Standard.ERC20)
            safeTransfer(trib.asset, user, trib.amount);
        else if (trib.std == Standard.ERC721)
            safeTransferFrom(trib.asset, address(this), user, trib.tokenId);
        else
            ERC1155STF(trib.asset).safeTransferFrom(
                address(this),
                user,
                trib.tokenId,
                trib.amount,
                ""
            );

        // Delete tribute escrow from storage so it can't be replayed.
        delete tributes[id];

        emit TributeReleased(user, id, false);
    }

    function _recoverSig(
        bytes32 hash,
        address from,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal view virtual {
        address signer;

        // Perform signature recovery via ecrecover.
        /// @solidity memory-safe-assembly
        assembly {
            // Copy the free memory pointer so that we can restore it later.
            let m := mload(0x40)

            // If `s` in lower half order, such that the signature is not malleable.
            if iszero(gt(s, MALLEABILITY_THRESHOLD)) {
                mstore(0x00, hash)
                mstore(0x20, v)
                mstore(0x40, r)
                mstore(0x60, s)
                pop(
                    staticcall(
                        gas(), // Amount of gas left for the transaction.
                        0x01, // Address of `ecrecover`.
                        0x00, // Start of input.
                        0x80, // Size of input.
                        0x40, // Start of output.
                        0x20 // Size of output.
                    )
                )
                // Restore the zero slot.
                mstore(0x60, 0)
                // `returndatasize()` will be `0x20` upon success, and `0x00` otherwise.
                signer := mload(sub(0x60, returndatasize()))
            }
            // Restore the free memory pointer.
            mstore(0x40, m)
        }

        // If recovery doesn't match `from`, verify contract signature with ERC1271.
        if (from != signer) {
            bool valid;

            /// @solidity memory-safe-assembly
            assembly {
                // Load the free memory pointer.
                // Simply using the free memory usually costs less if many slots are needed.
                let m := mload(0x40)

                // `bytes4(keccak256("isValidSignature(bytes32,bytes)"))`.
                let f := shl(224, 0x1626ba7e)
                // Write the abi-encoded calldata into memory, beginning with the function selector.
                mstore(m, f) // `bytes4(keccak256("isValidSignature(bytes32,bytes)"))`.
                mstore(add(m, 0x04), hash)
                mstore(add(m, 0x24), 0x40) // The offset of the `signature` in the calldata.
                mstore(add(m, 0x44), 65) // Store the length of the signature.
                mstore(add(m, 0x64), r) // Store `r` of the signature.
                mstore(add(m, 0x84), s) // Store `s` of the signature.
                mstore8(add(m, 0xa4), v) // Store `v` of the signature.

                valid := and(
                    and(
                        // Whether the returndata is the magic value `0x1626ba7e` (left-aligned).
                        eq(mload(0x00), f),
                        // Whether the returndata is exactly 0x20 bytes (1 word) long.
                        eq(returndatasize(), 0x20)
                    ),
                    // Whether the staticcall does not revert.
                    // This must be placed at the end of the `and` clause,
                    // as the arguments are evaluated from right to left.
                    staticcall(
                        gas(), // Remaining gas.
                        from, // The `from` address.
                        m, // Offset of calldata in memory.
                        0xa5, // Length of calldata in memory.
                        0x00, // Offset of returndata.
                        0x20 // Length of returndata to write.
                    )
                )
            }

            if (!valid) revert InvalidSig();
        }
    }
}
