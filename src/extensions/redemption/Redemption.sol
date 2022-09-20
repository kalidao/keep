// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @dev Interfaces.
import {IERC20Balances} from "../../interfaces/IERC20Balances.sol";
import {IKeep} from "../../interfaces/IKeep.sol";

/// @dev Libraries.
import {FixedPointMathLib} from "@solbase/utils/FixedPointMathLib.sol";
import {SafeTransferLib} from "@solbase/utils/SafeTransferLib.sol";

/// @dev Contracts.
import {ERC1155TokenReceiver} from "../../ERC1155V.sol";
import {Multicallable} from "@solbase/utils/Multicallable.sol";

/// @title Redemption
/// @notice Fair share redemptions for burnt treasury tokens.
/// @dev Based on Moloch DAO `ragequit()`.
contract Redemption is ERC1155TokenReceiver, Multicallable {
    /// -----------------------------------------------------------------------
    /// LIBRARY USAGE
    /// -----------------------------------------------------------------------

    using FixedPointMathLib for uint256;

    using SafeTransferLib for address;

    /// -----------------------------------------------------------------------
    /// EVENTS
    /// -----------------------------------------------------------------------

    event RedemptionStartSet(
        address indexed treasury,
        uint256 id,
        uint256 redemptionStart
    );

    event Redeemed(
        address indexed redeemer,
        address indexed treasury,
        address[] assets
    );

    /// -----------------------------------------------------------------------
    /// ERRORS
    /// -----------------------------------------------------------------------

    error NOT_STARTED();

    error INVALID_ASSET_ORDER();

    /// -----------------------------------------------------------------------
    /// STORAGE
    /// -----------------------------------------------------------------------

    mapping(address => mapping(uint256 => uint256)) public redemptionStarts;

    /// -----------------------------------------------------------------------
    /// CONFIGURATIONS
    /// -----------------------------------------------------------------------

    /// @notice Redemption configuration for treasuries.
    /// @param id The token ID to set redemption configuration for.
    /// @param redemptionStart The unix timestamp at which redemption starts.
    function setRedemptionStart(uint256 id, uint256 redemptionStart)
        public
        payable
        virtual
    {
        redemptionStarts[msg.sender][id] = redemptionStart;

        emit RedemptionStartSet(msg.sender, id, redemptionStart);
    }

    /// -----------------------------------------------------------------------
    /// REDEMPTIONS
    /// -----------------------------------------------------------------------

    /// @notice Redemption option for treasury holders.
    /// @param treasury Treasury contract address.
    /// @param assets Array of assets to redeem out.
    /// @param id The token ID to burn from.
    /// @param redemption Amount of token ID to burn.
    function redeem(
        address treasury,
        address[] calldata assets,
        uint256 id,
        uint256 redemption
    ) public payable virtual {
        if (block.timestamp < redemptionStarts[treasury][id]) 
            revert NOT_STARTED();

        uint256 supply = IKeep(treasury).totalSupply(id);

        IKeep(treasury).burn(msg.sender, id, redemption);

        address prevAddr;

        for (uint256 i; i < assets.length; ) {
            // Prevent null and duplicate assets.
            if (prevAddr >= assets[i]) revert INVALID_ASSET_ORDER();

            prevAddr = assets[i];

            // Calculate fair share of given assets for redemption.
            uint256 amountToRedeem = redemption.mulDivDown(
                IERC20Balances(assets[i]).balanceOf(treasury),
                supply
            );

            // Transfer from treasury to redeemer.
            if (amountToRedeem != 0)
                assets[i].safeTransferFrom(
                    treasury,
                    msg.sender,
                    amountToRedeem
                );

            // An array can't have a total length
            // larger than the max uint256 value.
            unchecked {
                ++i;
            }
        }

        emit Redeemed(msg.sender, treasury, assets);
    }
}
