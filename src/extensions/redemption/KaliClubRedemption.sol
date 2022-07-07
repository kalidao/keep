// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

/// @dev Interfaces
import {IERC20Balances} from "../../interfaces/IERC20Balances.sol";
import {IKaliClub} from "../../interfaces/IKaliClub.sol";

/// @dev Libraries
import {FixedPointMathLib} from "../../libraries/FixedPointMathLib.sol";
import {SafeTransferLib} from "../../libraries/SafeTransferLib.sol";

/// @title Kali Club Redemption
/// @notice Fair share redemptions for burnt Kali Club tokens
contract KaliClubRedemption {
    /// -----------------------------------------------------------------------
    /// LIBRARY USAGE
    /// -----------------------------------------------------------------------

    using FixedPointMathLib for uint256;

    using SafeTransferLib for address;

    /// -----------------------------------------------------------------------
    /// EVENTS
    /// -----------------------------------------------------------------------

    event ExtensionSet(address indexed club, uint256 id, uint256 redemptionStart);

    event ExtensionCalled(address indexed club, address indexed member, address[] assets, uint256 id, uint256 burnAmount);

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

    function setRedemption(uint256 id, uint256 redemptionStart) external payable {
        redemptionStarts[msg.sender][id] = redemptionStart;
    }

    /// -----------------------------------------------------------------------
    /// REDEMPTIONS
    /// -----------------------------------------------------------------------
    
    /// @notice Redemption option for club members
    /// @param club Kali Club contract address
    /// @param assets Array of assets to redeem out
    /// @param id The token ID to burn from
    /// @param burnAmount Amount of token ID to burn
    function redeem(
        address club, 
        address[] calldata assets, 
        uint256 id,
        uint256 burnAmount
    )
        external
        payable
    {
        if (block.timestamp < redemptionStarts[club][id]) revert NOT_STARTED();

        uint256 supply = IKaliClub(club).totalSupply(id);

        IKaliClub(club).burn(
            msg.sender, 
            id,
            burnAmount
        );
        
        address prevAddr;

        for (uint256 i; i < assets.length; ) {
            // prevent null and duplicate assets
            if (prevAddr >= assets[i]) revert INVALID_ASSET_ORDER();

            prevAddr = assets[i];

            // calculate fair share of given assets for redemption
            uint256 amountToRedeem = FixedPointMathLib._mulDivDown(
                burnAmount,
                IERC20Balances(assets[i]).balanceOf(club),
                supply
            );

            // transfer to redeemer
            if (amountToRedeem != 0) 
                assets[i]._safeTransferFrom(
                    club, 
                    msg.sender, 
                    amountToRedeem
                );

            // cannot realistically overflow
            unchecked {
                ++i;
            }
        }
    }
}
