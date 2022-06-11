// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

/// @notice A generic interface for a contract which properly accepts ERC-721 tokens
/// @author Modified from Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/tokens/ERC721.sol)
/// License-Identifier: MIT
interface ERC721TokenReceiver {
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

/// @notice Modern, minimalist, and gas efficient ERC-721 implementation designed for Kali ClubSig
/// @author Modified from Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/tokens/ERC721.sol)
/// License-Identifier: MIT
abstract contract ClubNFT {
    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------
    
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 indexed id
    );
    event ApprovalForAll(
        address indexed owner,
        address indexed operator,
        bool approved
    );
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed id
    );
    event PauseSet(bool paused);

    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    error Paused();
    error Forbidden();
    error NotOwner();
    error InvalidRecipient();
    error AlreadyMinted();
    error NotMinted();

    /// -----------------------------------------------------------------------
    /// Metadata Storage/Logic
    /// -----------------------------------------------------------------------

    function name() public pure returns (string memory) {
        return string(abi.encodePacked(_getArgUint256(0)));
    }

    function symbol() public pure returns (string memory) {
        return string(abi.encodePacked(_getArgUint256(0x20)));
    }

    function _getArgUint256(uint256 argOffset)
        private
        pure
        returns (uint256 arg)
    {
        uint256 offset = _getImmutableArgsOffset();

        assembly {
            arg := calldataload(add(offset, argOffset))
        }
    }

    function _getImmutableArgsOffset() internal pure returns (uint256 offset) {
        assembly {
            offset := sub(
                calldatasize(),
                add(shr(240, calldataload(sub(calldatasize(), 2))), 2)
            )
        }
    }

    /// -----------------------------------------------------------------------
    /// ERC-721 Storage
    /// -----------------------------------------------------------------------

    mapping(address => uint256) public balanceOf;
    mapping(uint256 => address) public ownerOf;
    mapping(uint256 => address) public getApproved;
    mapping(address => mapping(address => bool)) public isApprovedForAll;

    /// -----------------------------------------------------------------------
    /// Pause Storage/Logic
    /// -----------------------------------------------------------------------

    bool public paused;

    modifier pauseCheck() {
        if (paused) revert Paused();
        _;
    }

    /// -----------------------------------------------------------------------
    /// ERC-165 Logic
    /// -----------------------------------------------------------------------

    function supportsInterface(bytes4 interfaceId)
        external
        pure
        returns (bool)
    {
        return
            interfaceId == this.supportsInterface.selector || // ERC-165 Interface ID for ERC-165
            interfaceId == 0x80ac58cd || // ERC-165 Interface ID for ERC-721
            interfaceId == 0x5b5e139f; // ERC-165 Interface ID for ERC721Metadata
    }

    /// -----------------------------------------------------------------------
    /// ERC-721 Logic
    /// -----------------------------------------------------------------------

    function approve(address spender, uint256 id) external payable {
        address owner = ownerOf[id];

        if (msg.sender != owner && !isApprovedForAll[owner][msg.sender])
            revert Forbidden();

        getApproved[id] = spender;

        emit Approval(owner, spender, id);
    }

    function setApprovalForAll(address operator, bool approved)
        external
        payable
    {
        isApprovedForAll[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function transferFrom(
        address from,
        address to,
        uint256 id
    ) public payable pauseCheck {
        if (from != ownerOf[id]) revert NotOwner();
        if (to == address(0)) revert InvalidRecipient();
        if (
            msg.sender != from &&
            msg.sender != getApproved[id] &&
            !isApprovedForAll[from][msg.sender]
        ) revert Forbidden();
        // underflow of the sender's balance is impossible because we check for
        // ownership above and the recipient's balance can't realistically overflow
        unchecked {
            --balanceOf[from];
            ++balanceOf[to];
        }

        delete getApproved[id];

        ownerOf[id] = to;

        emit Transfer(from, to, id);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id
    ) external payable {
        transferFrom(from, to, id);

        if (to.code.length != 0) {
            if (
                ERC721TokenReceiver(to).onERC721Received(
                    msg.sender,
                    from,
                    id,
                    ''
                ) != ERC721TokenReceiver.onERC721Received.selector
            ) revert InvalidRecipient();
        }
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        bytes calldata data
    ) external payable {
        transferFrom(from, to, id);

        if (to.code.length != 0) {
            if (
                ERC721TokenReceiver(to).onERC721Received(
                    msg.sender,
                    from,
                    id,
                    data
                ) != ERC721TokenReceiver.onERC721Received.selector
            ) revert InvalidRecipient();
        }
    }

    /// -----------------------------------------------------------------------
    /// Internal Mint/Burn Logic
    /// -----------------------------------------------------------------------

    function _safeMint(address to, uint256 id) internal {
        if (to == address(0)) revert InvalidRecipient();
        if (ownerOf[id] != address(0)) revert AlreadyMinted();
        // cannot realistically overflow
        unchecked {
            ++balanceOf[to];
        }

        ownerOf[id] = to;

        emit Transfer(address(0), to, id);

        if (to.code.length != 0) {
            if (
                ERC721TokenReceiver(to).onERC721Received(
                    msg.sender,
                    address(0),
                    id,
                    ''
                ) != ERC721TokenReceiver.onERC721Received.selector
            ) revert InvalidRecipient();
        }
    }

    function _burn(uint256 id) internal {
        address owner = ownerOf[id];
        if (owner == address(0)) revert NotMinted();
        // ownership check ensures no underflow
        unchecked {
            --balanceOf[owner];
        }

        delete ownerOf[id];
        delete getApproved[id];

        emit Transfer(owner, address(0), id);
    }

    /// -----------------------------------------------------------------------
    /// Internal Pause Logic
    /// -----------------------------------------------------------------------

    function _setPause(bool paused_) internal {
        paused = paused_;
        emit PauseSet(paused_);
    }
}
