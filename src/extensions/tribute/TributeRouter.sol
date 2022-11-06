// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {ERC1155STF} from "@kali/utils/ERC1155STF.sol";
import {KeepTokenMint} from "./utils/KeepTokenMint.sol";
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
    uint128 amount;
    uint128 forAmount;
}

/// @author z0r0z.eth
contract TributeRouter is SelfPermit, ReentrancyGuard, SafeMulticallable {
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
        uint128 amount,
        uint96 forId,
        uint128 forAmount
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
    /// @return id The Keep escrow ID assigned incrementally for each tribute.
    /// @dev The `tokenId` will be used where tribute `asset` is ERC721 or ERC1155.
    function makeTribute(
        address to,
        address asset,
        Standard std,
        uint88 tokenId,
        uint128 amount,
        uint96 forId,
        uint128 forAmount
    ) public payable virtual nonReentrant returns (uint256 id) {
        // Unchecked because the only math done is incrementing
        // currentId which cannot realistically overflow.
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
                forAmount: forAmount
            });
        }

        // If user attaches ETH, handle as tribute.
        // Otherwise, token transfer performed.
        if (msg.value != 0)
            if (msg.value != amount)
                if (std != Standard.ETH) revert InvalidETHTribute();
                else if (std == Standard.ERC20)
                    safeTransferFrom(asset, msg.sender, address(this), amount);
                else if (std == Standard.ERC721)
                    safeTransferFrom(asset, msg.sender, address(this), tokenId);
                else
                    ERC1155STF(asset).safeTransferFrom(
                        msg.sender,
                        address(this),
                        tokenId,
                        amount,
                        ""
                    );

        emit TributeMade(
            id, // Tribute escrow ID.
            msg.sender, // Tribute proposer.
            to,
            asset,
            std,
            tokenId,
            amount,
            forId,
            forAmount
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
}
