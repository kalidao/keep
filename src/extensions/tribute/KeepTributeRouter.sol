// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {ReentrancyGuard} from "@solbase/src/utils/ReentrancyGuard.sol";

import {safeTransferETH, safeTransfer, safeTransferFrom} from "@solbase/src/utils/SafeTransfer.sol";

import {KeepTokenMint} from "./utils/KeepTokenMint.sol";

/// @notice Moloch-style Keep tribute router in ETH and ERC20/721.
/// @dev This extension is enabled while it holds a Keep mint ID key.
contract KeepTributeRouter is ReentrancyGuard {
    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event MakeTribute(
        uint256 id,
        address from,
        address to,
        address asset,
        uint256 tribute,
        uint256 forId,
        uint256 forAmount
    );

    event ReleaseTribute(address operator, uint256 id, bool approve);

    /// -----------------------------------------------------------------------
    /// Custom Errors
    /// -----------------------------------------------------------------------

    error InsufficientETH();

    error Unauthorized();

    /// -----------------------------------------------------------------------
    /// Tribute Storage
    /// -----------------------------------------------------------------------

    uint256 internal constant MINT_KEY =
        uint32(KeepTokenMint.balanceOf.selector);

    uint256 public currentId;

    mapping(uint256 => Tribute) public tributes;

    struct Tribute {
        address from;
        address to;
        address asset;
        uint96 tribute;
        uint96 forId;
        uint96 forAmount;
    }

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
    /// @param asset The asset type to make tribute in.
    /// @param tribute The amout of asset to make tribute in.
    /// @param forId The ERC1155 Keep token ID to make tribute for.
    /// @param forAmount The ERC1155 Keep token ID amount to make tribute for.
    /// @return id The Keep escrow ID assigned incrementally for each tribute.
    function makeTribute(
        address to,
        address asset,
        uint256 tribute,
        uint256 forId,
        uint256 forAmount
    ) public payable virtual nonReentrant returns (uint256 id) {
        // Unchecked because the only math done is incrementing
        // currentId which cannot realistically overflow.
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

        // If user selects zero address `asset`, ETH is handled.
        // Otherwise, token transfer performed.
        if (asset == address(0) && msg.value != tribute)
            revert InsufficientETH();
        else safeTransferFrom(asset, msg.sender, address(this), tribute);

        emit MakeTribute(
            // Tribute escrow ID.
            id,
            // Tribute proposer.
            msg.sender,
            to,
            asset,
            tribute,
            forId,
            forAmount
        );
    }

    /// @notice Escrow release for a Keep token mint.
    /// @param id The escrow ID to activate tribute release for.
    /// @param approve If `true`, escrow will release to Keep for mint.
    /// If `false, tribute will be returned back to the tribute proposer.
    /// @dev Calls are permissioned to the Keep itself or mint ID key holder.
    function releaseTribute(uint256 id, bool approve)
        public
        payable
        virtual
        nonReentrant
    {
        // Fetch tribute details from storage.
        Tribute storage trib = tributes[id];

        // Check permissions for tribute release.
        if (
            msg.sender != trib.to &&
            KeepTokenMint(trib.to).balanceOf(msg.sender, MINT_KEY) == 0
        ) revert Unauthorized();

        // Branch release and minting on approval,
        // as well as on whether asset is ETH or token.
        if (approve) {
            trib.asset == address(0)
                ? safeTransferETH(trib.to, trib.tribute)
                : safeTransfer(trib.asset, trib.to, trib.tribute);

            KeepTokenMint(trib.to).mint(
                trib.to,
                trib.forId,
                trib.forAmount,
                ""
            );
        } else {
            trib.asset == address(0)
                ? safeTransferETH(trib.from, trib.tribute)
                : safeTransfer(trib.asset, trib.from, trib.tribute);
        }

        emit ReleaseTribute(msg.sender, id, approve);
    }
}
