// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice ERC721 interface to receive tokens.
/// @author Modified from SolDAO (https://github.com/Sol-DAO/solbase/blob/main/src/tokens/ERC721/ERC721.sol)
abstract contract ERC721TokenReceiver {
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) public payable virtual returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
