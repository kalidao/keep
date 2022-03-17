// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

/// @notice Receiver utility for NFT 'safe' transfers
abstract contract NFTreceiver {
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return 0x150b7a02; 
        // 'onERC721Received(address,address,uint256,bytes)'
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return 0xf23a6e61; 
        // 'onERC1155Received(address,address,uint256,uint256,bytes)'
    }
    
    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external pure returns (bytes4) {
        return 0xbc197c81; 
        // 'onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)'
    }
}
