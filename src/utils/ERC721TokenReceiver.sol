// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice A generic interface for a contract which properly accepts ERC721 tokens.
/// @author Modified from Solmate (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC721.sol)
abstract contract ERC721TokenReceiver {
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external payable virtual returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
