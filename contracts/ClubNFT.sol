// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity >=0.8.4;

/// @notice A generic interface for a contract which properly accepts ERC-721 tokens
/// @author Modified from Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/tokens/ERC721.sol)
/// License-Identifier: AGPL-3.0-only
interface ERC721TokenReceiver {
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

/// @notice Modern and gas efficient ERC-721 + ERC-20/EIP-2612-like implementation
/// @author Modified from Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/tokens/ERC721.sol)
/// License-Identifier: AGPL-3.0-only
abstract contract ClubNFT {
    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event Transfer(address indexed from, address indexed to, uint256 indexed id);
    event Approval(address indexed owner, address indexed spender, uint256 indexed id);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
    event PauseFlipped(bool paused);

    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    error Paused();
    error NotOwner();
    error Forbidden();
    error InvalidRecipient();
    error SignatureExpired();
    error InvalidSignature();
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

    function _getArgUint256(uint256 argOffset) internal pure returns (uint256 arg) {
        uint256 offset;
        
        assembly {
            offset := sub(
                calldatasize(),
                add(shr(240, calldataload(sub(calldatasize(), 2))), 2)
            )
        }

        assembly {
            arg := calldataload(add(offset, argOffset))
        }
    }

    /// -----------------------------------------------------------------------
    /// EIP-712 Storage/Logic
    /// -----------------------------------------------------------------------
    
    uint256 internal INITIAL_CHAIN_ID;
    bytes32 internal INITIAL_DOMAIN_SEPARATOR;

    mapping(uint256 => uint256) public nonces;
    mapping(address => uint256) public noncesForAll;

    struct Signature {
	uint8 v;
	bytes32 r;
        bytes32 s;
    }

    function DOMAIN_SEPARATOR() public view returns (bytes32) {
        return block.chainid == INITIAL_CHAIN_ID ? INITIAL_DOMAIN_SEPARATOR : _computeDomainSeparator();
    }

    function _computeDomainSeparator() internal view returns (bytes32) {
        return 
            keccak256(
                abi.encode(
                    keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'),
                    keccak256(bytes(name())),
                    keccak256('1'),
                    block.chainid,
                    address(this)
                )
            );
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

    modifier notPaused() {
        if (paused) revert Paused();
        _;
    }
    
    /// -----------------------------------------------------------------------
    /// Initializer
    /// -----------------------------------------------------------------------
    
    function _init(bool paused_) internal {
        paused = paused_;
        INITIAL_CHAIN_ID = block.chainid;
        INITIAL_DOMAIN_SEPARATOR = _computeDomainSeparator();
    }

    /// -----------------------------------------------------------------------
    /// ERC-165 Logic
    /// -----------------------------------------------------------------------

    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC-165 Interface ID for ERC-165
            interfaceId == 0x80ac58cd || // ERC-165 Interface ID for ERC-721
            interfaceId == 0x5b5e139f; // ERC-165 Interface ID for ERC721Metadata
    }
    
    /// -----------------------------------------------------------------------
    /// ERC-20-like Logic (EIP-4521)
    /// -----------------------------------------------------------------------
    
    function transfer(address to, uint256 id) public payable notPaused returns (bool) {
        if (msg.sender != ownerOf[id]) revert NotOwner();
        if (to == address(0)) revert InvalidRecipient();
        
        // underflow of the sender's balance is impossible because we check for
        // ownership above and the recipient's balance can't realistically overflow
        unchecked {
            balanceOf[msg.sender]--; 
            balanceOf[to]++;
        }
        
        delete getApproved[id];
        
        ownerOf[id] = to;
        
        emit Transfer(msg.sender, to, id); 
        
        return true;
    }

    /// -----------------------------------------------------------------------
    /// ERC-721 Logic
    /// -----------------------------------------------------------------------
    
    function approve(address spender, uint256 id) public payable {
        address owner = ownerOf[id];

        if (msg.sender != owner && !isApprovedForAll[owner][msg.sender]) revert Forbidden();
        
        getApproved[id] = spender;
        
        emit Approval(owner, spender, id); 
    }
    
    function setApprovalForAll(address operator, bool approved) public payable {
        isApprovedForAll[msg.sender][operator] = approved;
        
        emit ApprovalForAll(msg.sender, operator, approved);
    }
    
    function transferFrom(
        address from, 
        address to, 
        uint256 id
    ) public payable notPaused {
        if (from != ownerOf[id]) revert NotOwner();
        if (to == address(0)) revert InvalidRecipient();
        if (msg.sender != from 
            && msg.sender != getApproved[id]
            && !isApprovedForAll[from][msg.sender]
        ) revert Forbidden();  
        
        // underflow of the sender's balance is impossible because we check for
        // ownership above and the recipient's balance can't realistically overflow
        unchecked { 
            balanceOf[from]--; 
            balanceOf[to]++;
        }
        
        delete getApproved[id];
        
        ownerOf[id] = to;
        
        emit Transfer(from, to, id); 
    }
    
    function safeTransferFrom(
        address from, 
        address to, 
        uint256 id
    ) public payable notPaused {
        transferFrom(from, to, id); 

        if (to.code.length != 0 
            && ERC721TokenReceiver(to).onERC721Received(msg.sender, from, id, '') 
            != ERC721TokenReceiver.onERC721Received.selector
        ) revert InvalidRecipient();
    }
    
    function safeTransferFrom(
        address from, 
        address to, 
        uint256 id, 
        bytes calldata data
    ) public payable notPaused {
        transferFrom(from, to, id); 
        
        if (to.code.length != 0 
            && ERC721TokenReceiver(to).onERC721Received(msg.sender, from, id, data) 
            != ERC721TokenReceiver.onERC721Received.selector
        ) revert InvalidRecipient();
    }

    /// -----------------------------------------------------------------------
    /// EIP-2612-like Logic
    /// -----------------------------------------------------------------------
    
    function permit(
        address spender,
        uint256 id,
        uint256 deadline,
        Signature calldata sig
    ) public payable {
        if (block.timestamp > deadline) revert SignatureExpired();
        
        address owner = ownerOf[id];
        
        // cannot realistically overflow on human timescales
        unchecked {
            bytes32 digest = keccak256(
                abi.encodePacked(
                    '\x19\x01',
                    DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(keccak256(
                        'Permit(address spender,uint256 id,uint256 nonce,uint256 deadline)'), 
                        spender, id, nonces[id]++, deadline))
                )
            );

            address recoveredAddress = ecrecover(digest, sig.v, sig.r, sig.s);

            if (recoveredAddress != owner 
                && !isApprovedForAll[owner][recoveredAddress]
                || recoveredAddress == address(0)
            ) revert InvalidSignature(); 
        }
        
        getApproved[id] = spender;

        emit Approval(owner, spender, id);
    }
    
    function permitAll(
        address owner,
        address operator,
        uint256 deadline,
        Signature calldata sig
    ) public payable {
        if (block.timestamp > deadline) revert SignatureExpired();
        
        // cannot realistically overflow on human timescales
        unchecked {
            bytes32 digest = keccak256(
                abi.encodePacked(
                    '\x19\x01',
                    DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(keccak256(
                        'Permit(address owner,address operator,uint256 nonce,uint256 deadline)'), 
                        owner, operator, noncesForAll[owner]++, deadline))
                )
            );

            address recoveredAddress = ecrecover(digest, sig.v, sig.r, sig.s);

            if (recoveredAddress == address(0)) revert InvalidSignature();
            if (recoveredAddress != owner && !isApprovedForAll[owner][recoveredAddress]) revert InvalidSignature();
        }
        
        isApprovedForAll[owner][operator] = true;

        emit ApprovalForAll(owner, operator, true);
    }

    /// -----------------------------------------------------------------------
    /// Internal Mint/Burn Logic
    /// -----------------------------------------------------------------------

    function _safeMint(address to, uint256 id) internal {
        if (to == address(0)) revert InvalidRecipient();
        if (ownerOf[id] != address(0)) revert AlreadyMinted();
  
        // cannot realistically overflow on human timescales
        unchecked {
            balanceOf[to]++;
        }
        
        ownerOf[id] = to;
        
        emit Transfer(address(0), to, id); 

        if (to.code.length != 0 
            && ERC721TokenReceiver(to).onERC721Received(msg.sender, address(0), id, '') 
            != ERC721TokenReceiver.onERC721Received.selector
        ) revert InvalidRecipient();
    }

    function _burn(uint256 id) internal { 
        address owner = ownerOf[id];

        if (ownerOf[id] == address(0)) revert NotMinted();
        
        // ownership check ensures no underflow
        unchecked {
            balanceOf[owner]--;
        }
        
        delete ownerOf[id];
        delete getApproved[id];
        
        emit Transfer(owner, address(0), id); 
    }

    /// -----------------------------------------------------------------------
    /// Internal Pause Logic
    /// -----------------------------------------------------------------------

    function _flipPause() internal {
        paused = !paused;

        emit PauseFlipped(paused);
    }
}
