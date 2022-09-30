// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice A generic interface for a contract which properly accepts ERC721 tokens.
/// @author Modified from Solbase (https://github.com/Sol-DAO/solbase/blob/main/src/tokens/ERC721/ERC721.sol)
abstract contract ERC721TokenReceiver {
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external payable virtual returns (bytes4) {
        return ERC721TokenReceiver.onERC721Received.selector;
    }
}
