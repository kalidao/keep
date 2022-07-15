// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

/// @dev Interfaces
import {IERC20Balances} from "../../interfaces/IERC20Balances.sol";
import {IKeep} from "../../interfaces/IKeep.sol";

/// @dev Libraries
import {MulDivDownLib} from "../../libraries/MulDivDownLib.sol";
import {SafeTransferLib} from "../../libraries/SafeTransferLib.sol";

/// @dev Contracts
import {ERC1155TokenReceiver} from "../../ERC1155Votes.sol";
import {Multicall} from "../../utils/Multicall.sol";

/// @title Redemption
/// @notice Fair share redemptions for burnt treasury tokens
/// @dev Based on Moloch DAO ragequit()
contract Redemption is ERC1155TokenReceiver, Multicall {
    /// -----------------------------------------------------------------------
    /// LIBRARY USAGE
    /// -----------------------------------------------------------------------

    using MulDivDownLib for uint256;

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
        address[] assets,
        uint256 id,
        uint256 redemption
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

    /// @notice Redemption configuration for treasuries
    /// @param id The token ID to set redemption configuration for
    /// @param redemptionStart The unix timestamp at which redemption starts
    function setRedemptionStart(uint256 id, uint256 redemptionStart)
        external
        payable
    {
        redemptionStarts[msg.sender][id] = redemptionStart;

        emit RedemptionStartSet(msg.sender, id, redemptionStart);
    }

    /// -----------------------------------------------------------------------
    /// REDEMPTIONS
    /// -----------------------------------------------------------------------

    /// @notice Redemption option for treasury holders
    /// @param treasury Treasury contract address
    /// @param assets Array of assets to redeem out
    /// @param id The token ID to burn from
    /// @param redemption Amount of token ID to burn
    function redeem(
        address treasury,
        address[] calldata assets,
        uint256 id,
        uint256 redemption
    ) external payable {
        uint256 start = redemptionStarts[treasury][id];

        if (start == 0 || block.timestamp < start) revert NOT_STARTED();

        uint256 supply = IKeep(treasury).totalSupply(id);

        IKeep(treasury).burn(msg.sender, id, redemption);

        address prevAddr;

        for (uint256 i; i < assets.length; ) {
            // prevent null and duplicate assets
            if (prevAddr >= assets[i]) revert INVALID_ASSET_ORDER();

            prevAddr = assets[i];

            // calculate fair share of given assets for redemption
            uint256 amountToRedeem = redemption.mulDivDown(
                IERC20Balances(assets[i]).balanceOf(treasury),
                supply
            );

            // transfer from treasury to redeemer
            if (amountToRedeem != 0)
                assets[i].safeTransferFrom(
                    treasury,
                    msg.sender,
                    amountToRedeem
                );

            // an array can't have a total length
            // larger than the max uint256 value
            unchecked {
                ++i;
            }
        }

        emit Redeemed(msg.sender, treasury, assets, id, redemption);
    }
}
