// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity >=0.8.4;

/// @notice A generic interface for a contract which properly accepts ERC721 tokens
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
    /// ERC-165 Logic
    /// -----------------------------------------------------------------------

    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC-165 Interface ID for ERC-165
            interfaceId == 0x80ac58cd || // ERC-165 Interface ID for ERC-721
            interfaceId == 0x5b5e139f; // ERC-165 Interface ID for ERC721Metadata
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

            if (recoveredAddress == address(0)) revert InvalidSignature();
            if (recoveredAddress != owner && !isApprovedForAll[owner][recoveredAddress]) revert InvalidSignature(); 
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

/// @notice Provides a function for encoding some bytes in base64
/// @author Modified from Brecht Devos (https://github.com/Brechtpd/base64/blob/main/base64.sol)
/// License-Identifier: MIT
library Base64 {
    bytes internal constant TABLE = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

    /// @dev encodes some bytes to the base64 representation
    function encode(bytes memory data) internal pure returns (string memory) {
        uint256 len = data.length;
        if (len == 0) return '';

        // multiply by 4/3 rounded up
        uint256 encodedLen = 4 * ((len + 2) / 3);

        // add some extra buffer at the end
        bytes memory result = new bytes(encodedLen + 32);
        
        bytes memory table = TABLE;

        assembly {
            let tablePtr := add(table, 1)
            let resultPtr := add(result, 32)

            for {
                let i := 0
            } lt(i, len) {
            } {
                i := add(i, 3)
                let input := and(mload(add(data, i)), 0xffffff)

                let out := mload(add(tablePtr, and(shr(18, input), 0x3F)))
                out := shl(8, out)
                out := add(out, and(mload(add(tablePtr, and(shr(12, input), 0x3F))), 0xFF))
                out := shl(8, out)
                out := add(out, and(mload(add(tablePtr, and(shr(6, input), 0x3F))), 0xFF))
                out := shl(8, out)
                out := add(out, and(mload(add(tablePtr, and(input, 0x3F))), 0xFF))
                out := shl(224, out)

                mstore(resultPtr, out)

                resultPtr := add(resultPtr, 4)
            }

            switch mod(len, 3)

            case 1 {
                mstore(sub(resultPtr, 2), shl(240, 0x3d3d))
            }

            case 2 {
                mstore(sub(resultPtr, 1), shl(248, 0x3d))
            }

            mstore(result, encodedLen)
        }

        return string(result);
    }
}

/// @notice Safe ERC20 transfer library that gracefully handles missing return values
/// @author Modified from Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/utils/SafeTransferLib.sol)
/// License-Identifier: AGPL-3.0-only
library SafeTransferTokenLib {
    error TransferFailed();

    function _safeTransfer(
        address token,
        address to,
        uint256 amount
    ) internal {
        bool callStatus;
        assembly {
            // get a pointer to some free memory
            let freeMemoryPointer := mload(0x40)
            // write the abi-encoded calldata to memory piece by piece:
            mstore(freeMemoryPointer, 0xa9059cbb00000000000000000000000000000000000000000000000000000000) // begin with the function selector
            mstore(add(freeMemoryPointer, 4), and(to, 0xffffffffffffffffffffffffffffffffffffffff)) // mask and append the "to" argument
            mstore(add(freeMemoryPointer, 36), amount) // finally append the "amount" argument - no mask as it's a full 32 byte value
            // call the token and store if it succeeded or not
            // we use 68 because the calldata length is 4 + 32 * 2
            callStatus := call(gas(), token, 0, freeMemoryPointer, 68, 0, 0)
        }
        if (!_didLastOptionalReturnCallSucceed(callStatus)) revert TransferFailed();
    }

    function _didLastOptionalReturnCallSucceed(bool callStatus) private pure returns (bool success) {
        assembly {
            // if the call reverted:
            if iszero(callStatus) {
                // copy the revert message into memory
                returndatacopy(0, 0, returndatasize())

                // revert with the same message.
                revert(0, returndatasize())
            }

            switch returndatasize()
            case 32 {
                // copy the return data into memory
                returndatacopy(0, 0, returndatasize())

                // set success to whether it returned true
                success := iszero(iszero(mload(0)))
            }
            case 0 {
                // there was no return data
                success := 1
            }
            default {
                // it returned some malformed output
                success := 0
            }
        }
    }
}

/// @notice Helper utility that enables calling multiple local methods in a single call
/// @author Modified from Uniswap (https://github.com/Uniswap/v3-periphery/blob/main/contracts/base/Multicall.sol)
/// License-Identifier: GPL-2.0-or-later
abstract contract Multicall {
    function multicall(bytes[] calldata data) public payable returns (bytes[] memory results) {
        results = new bytes[](data.length);
        
        // cannot realistically overflow on human timescales
        unchecked {
            for (uint256 i = 0; i < data.length; i++) {
                (bool success, bytes memory result) = address(this).delegatecall(data[i]);

                if (!success) {
                    if (result.length < 68) revert();
                    
                    assembly {
                        result := add(result, 0x04)
                    }
                    
                    revert(abi.decode(result, (string)));
                }

                results[i] = result;
            }
        }
    }
}

/// @notice Helper utility for NFT 'safe' transfers
abstract contract NFThelper {
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return 0x150b7a02; // 'onERC721Received(address,address,uint256,bytes)'
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return 0xf23a6e61; // 'onERC1155Received(address,address,uint256,uint256,bytes)'
    }
    
    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external pure returns (bytes4) {
        return 0xbc197c81; // 'onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)'
    }
}

/// @notice Minimal ERC-20 interface
interface IERC20minimal { 
    function balanceOf(address account) external view returns (uint256);
}

/// @notice ERC-1271 interface
interface IERC1271 {
    function isValidSignature(bytes32 hash, bytes calldata signature) external view returns (bytes4);
}

/// @notice EIP-712-signed multi-signature contract with NFT identifiers for signers and ragequit
/// @author Modified from MultiSignatureWallet (https://github.com/SilentCicero/MultiSignatureWallet)
/// License-Identifier: MIT
/// and LilGnosis (https://github.com/m1guelpf/lil-web3/blob/main/src/LilGnosis.sol)
/// License-Identifier: AGPL-3.0-only
contract ClubSig is ClubNFT, Multicall {
    /// -----------------------------------------------------------------------
    /// Library usage
    /// -----------------------------------------------------------------------
    using SafeTransferTokenLib for address;

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event Execute(address indexed target, uint256 value, bytes payload);
    event Govern(Club[] club, bool[] mints, uint256 quorum);

    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    error Initialized();
    error NoArrayParity();
    error SigBounds();
    error InvalidSigner();
    error ExecuteFailed();
    error NotSigner();
    error AssetOrder();

    /// -----------------------------------------------------------------------
    /// Club Storage
    /// -----------------------------------------------------------------------

    /// @dev initialized at `1` for cheaper first tx
    uint256 public nonce;
    /// @dev signature (NFT) threshold to execute tx
    uint256 public quorum;
    /// @dev optional metadata to signify contract
    string public baseURI;
    /// @dev total signer units minted
    uint256 public totalSupply;
    /// @dev total ragequittable units minted
    uint256 public totalLoot;
    /// @dev ragequittable units per account
    mapping(address => uint256) public loot;
    /// @dev administrative account tracking
    mapping(address => bool) public governor;

    struct Call {
        address target; 
        uint256 value;
        bytes payload;
        bool std; // if not, delegate call
    }

    /// -----------------------------------------------------------------------
    /// Initializer
    /// -----------------------------------------------------------------------

    struct Club {
        address signer;
        uint256 id;
        uint256 loot;
    }

    function init(
        Club[] calldata club_,
        uint256 quorum_,
        bool paused_,
        string memory baseURI_
    ) public payable {
        if (nonce != 0) revert Initialized();

        ClubNFT._init(paused_);

        uint256 length = club_.length;

        if (quorum_ > length) revert SigBounds();

        uint256 nftSupply;
        uint256 lootSupply;

        for (uint256 i = 0; i < length;) {
            _safeMint(club_[i].signer, club_[i].id);
            loot[club_[i].signer] = club_[i].loot;
            lootSupply += club_[i].loot;
            
            // cannot realistically overflow on human timescales
            unchecked {
                i++;
                nftSupply++;
            }
        }

        totalSupply = nftSupply;
        totalLoot = lootSupply;

        nonce = 1;
        quorum = quorum_;
        baseURI = baseURI_;
    }

    /// -----------------------------------------------------------------------
    /// Metadata Logic
    /// -----------------------------------------------------------------------

    function tokenURI(uint256 id) public view returns (string memory) {
        bytes memory base = bytes(baseURI);
        return base.length != 0 ? baseURI : _buildTokenURI(id);
    }

    function _buildTokenURI(uint256 id) internal view returns (string memory) {
        address owner = ownerOf[id];

        string memory metaSVG = string(
            abi.encodePacked(
                '<text dominant-baseline="middle" text-anchor="middle" fill="white" x="50%" y="90px">',
                '0x',
                _addressToString(owner),
                '</text>',
                '<text dominant-baseline="middle" text-anchor="middle" fill="white" x="100%" y="180px">',
                _uintToString(loot[owner]),
                ' Loot',
                '</text>'
            )
        );
        bytes memory svg = abi.encodePacked(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400" preserveAspectRatio="xMidYMid meet" style="font:14px serif"><rect width="400" height="400" fill="black" />',
            metaSVG,
            '</svg>'
        );
        bytes memory image = abi.encodePacked(
            'data:image/svg+xml;base64,',
            Base64.encode(bytes(svg))
        );
        return string(
            abi.encodePacked(
                'data:application/json;base64,',
                Base64.encode(
                    bytes(
                        abi.encodePacked(
                            '{"name":"',
                            name(),
                            '", "image":"',
                            image,
                            '", "description": "The holder of this NFT is a club key signer with impeccable taste."}'
                        )
                    )
                )
            )
        );
    }

    function _addressToString(address addr) internal pure returns (string memory) {
        bytes memory s = new bytes(40);
        for (uint i = 0; i < 20; i++) {
            bytes1 b = bytes1(uint8(uint(uint160(addr)) / (2**(8*(19 - i)))));
            bytes1 hi = bytes1(uint8(b) / 16);
            bytes1 lo = bytes1(uint8(b) - 16 * uint8(hi));
            s[2*i] = _char(hi);
            s[2*i+1] = _char(lo);            
        }
        return string(s);
    }

    function _char(bytes1 b) internal pure returns (bytes1 c) {
        if (uint8(b) < 10) return bytes1(uint8(b) + 0x30);
        else return bytes1(uint8(b) + 0x57);
    }

    function _uintToString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return '0';
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    /// -----------------------------------------------------------------------
    /// Operations
    /// -----------------------------------------------------------------------

    function execute(Call calldata call, Signature[] calldata sigs) public payable returns (bool success, bytes memory result) {
        // cannot realistically overflow on human timescales
        unchecked {
            bytes32 digest = keccak256(abi.encodePacked('\x19\x01', DOMAIN_SEPARATOR(),
                keccak256(abi.encode(keccak256(
                    'Exec(address target,uint256 value,bytes payload,bool std,uint256 nonce)'),
                    call.target, call.value, call.payload, call.std, nonce++)))
                );

            address prevAddr;

            for (uint256 i = 0; i < quorum; i++) {
                address signer = ecrecover(digest, sigs[i].v, sigs[i].r, sigs[i].s);

                // check for conformant contract signature
                if (signer.code.length != 0 && IERC1271(signer).isValidSignature(
                        digest, abi.encodePacked(sigs[i].r, sigs[i].s, sigs[i].v)) != 0x1626ba7e
                    ) revert InvalidSigner();

                // check for NFT balance and duplicates
                if (balanceOf[signer] == 0 || prevAddr >= signer) revert InvalidSigner();

                prevAddr = signer;
            }
        }
       
        if (call.std) {
            (success, result) = call.target.call{value: call.value}(call.payload);
            if (!success) revert ExecuteFailed();
        } else { // delegate call
            (success, result) = call.target.delegatecall(call.payload);
            if (!success) revert ExecuteFailed();
        }

        emit Execute(call.target, call.value, call.payload);
    }

    function govern(
        Club[] calldata club_,
        bool[] calldata mints_,
        uint256 quorum_
    ) public payable {
        if (msg.sender != address(this) && !governor[msg.sender]) revert Forbidden();

        uint256 length = club_.length;

        if (length != mints_.length) revert NoArrayParity();

        // cannot realistically overflow on human timescales
        unchecked {
            uint256 nftSupply;
            uint256 lootSupply;
            for (uint256 i = 0; i < length; i++) {
                if (mints_[i]) {
                    _safeMint(club_[i].signer, club_[i].id);
                    nftSupply++;
                } else {
                    _burn(club_[i].id);
                    if (nftSupply != 0) nftSupply--;
                }
                if (club_[i].loot != 0) {
                    loot[club_[i].signer] += club_[i].loot;
                    lootSupply += club_[i].loot;
                }
                if (nftSupply != 0) totalSupply += nftSupply;
                if (lootSupply != 0) totalLoot += lootSupply;
            }
        }

        if (quorum_ > totalSupply) revert SigBounds();

        quorum = quorum_;

        emit Govern(club_, mints_, quorum_);
    }
    
    function governorExecute(Call calldata call) public payable returns (bool success, bytes memory result) {
        if (!governor[msg.sender]) revert Forbidden();

        if (call.std) {
            (success, result) = call.target.call{value: call.value}(call.payload);
            if (!success) revert ExecuteFailed();
        } else {
            (success, result) = call.target.delegatecall(call.payload);
            if (!success) revert ExecuteFailed();
        }
    }

    function flipGovernor(address account) public payable {
        if (msg.sender != address(this) && !governor[msg.sender]) revert Forbidden();

        governor[account] = !governor[account];
    }

    function flipPause() public payable {
        if (msg.sender != address(this) && !governor[msg.sender]) revert Forbidden();

        ClubNFT._flipPause();
    }

    /// -----------------------------------------------------------------------
    /// Asset Management
    /// -----------------------------------------------------------------------

    receive() external payable {}

    function ragequit(address[] calldata assets, uint256 lootToBurn) public payable {
        uint256 length = assets.length;

        // cannot realistically overflow on human timescales
        unchecked {
            for (uint256 i; i < length; i++) {
                if (i != 0) {
                    if (assets[i] <= assets[i - 1]) revert AssetOrder();
                }
            }
        }

        uint256 lootTotal = totalLoot;
        loot[msg.sender] -= lootToBurn;

        // cannot realistically overflow on human timescales
        unchecked {
            totalLoot -= lootToBurn;
        }

        for (uint256 i; i < length;) {
            // calculate fair share of given assets for redemption
            uint256 amountToRedeem = lootToBurn * IERC20minimal(assets[i]).balanceOf(address(this)) / 
                lootTotal;
            // transfer to redeemer
            if (amountToRedeem != 0)
                assets[i]._safeTransfer(msg.sender, amountToRedeem);
            // cannot realistically overflow on human timescales
            unchecked {
                i++;
            }
        }
    }
}

/// @title ClonesWithImmutableArgs
/// @author wighawag, zefram.eth
/// @notice Enables creating clone contracts with immutable args
library ClonesWithImmutableArgs {
    error CreateFail();

    /// @notice Creates a clone proxy of the implementation contract, with immutable args
    /// @dev data cannot exceed 65535 bytes, since 2 bytes are used to store the data length
    /// @param implementation The implementation contract to clone
    /// @param data Encoded immutable args
    /// @return instance The address of the created clone
    function clone(address implementation, bytes memory data)
        internal
        returns (address payable instance)
    {
        // unrealistic for memory ptr or data length to exceed 256 bits
        unchecked {
            uint256 extraLength = data.length + 2; // +2 bytes for telling how much data there is appended to the call
            uint256 creationSize = 0x41 + extraLength;
            uint256 runSize = creationSize - 10;
            uint256 dataPtr;
            uint256 ptr;
            // solhint-disable-next-line no-inline-assembly
            assembly {
                ptr := mload(0x40)

                // -------------------------------------------------------------------------------------------------------------
                // CREATION (10 bytes)
                // -------------------------------------------------------------------------------------------------------------

                // 61 runtime  | PUSH2 runtime (r)     | r                       | –
                mstore(
                    ptr,
                    0x6100000000000000000000000000000000000000000000000000000000000000
                )
                mstore(add(ptr, 0x01), shl(240, runSize)) // size of the contract running bytecode (16 bits)

                // creation size = 0a
                // 3d          | RETURNDATASIZE        | 0 r                     | –
                // 81          | DUP2                  | r 0 r                   | –
                // 60 creation | PUSH1 creation (c)    | c r 0 r                 | –
                // 3d          | RETURNDATASIZE        | 0 c r 0 r               | –
                // 39          | CODECOPY              | 0 r                     | [0-runSize): runtime code
                // f3          | RETURN                |                         | [0-runSize): runtime code

                // -------------------------------------------------------------------------------------------------------------
                // RUNTIME (55 bytes + extraLength)
                // -------------------------------------------------------------------------------------------------------------

                // 3d          | RETURNDATASIZE        | 0                       | –
                // 3d          | RETURNDATASIZE        | 0 0                     | –
                // 3d          | RETURNDATASIZE        | 0 0 0                   | –
                // 3d          | RETURNDATASIZE        | 0 0 0 0                 | –
                // 36          | CALLDATASIZE          | cds 0 0 0 0             | –
                // 3d          | RETURNDATASIZE        | 0 cds 0 0 0 0           | –
                // 3d          | RETURNDATASIZE        | 0 0 cds 0 0 0 0         | –
                // 37          | CALLDATACOPY          | 0 0 0 0                 | [0, cds) = calldata
                // 61          | PUSH2 extra           | extra 0 0 0 0           | [0, cds) = calldata
                mstore(
                    add(ptr, 0x03),
                    0x3d81600a3d39f33d3d3d3d363d3d376100000000000000000000000000000000
                )
                mstore(add(ptr, 0x13), shl(240, extraLength))

                // 60 0x37     | PUSH1 0x37            | 0x37 extra 0 0 0 0      | [0, cds) = calldata // 0x37 (55) is runtime size - data
                // 36          | CALLDATASIZE          | cds 0x37 extra 0 0 0 0  | [0, cds) = calldata
                // 39          | CODECOPY              | 0 0 0 0                 | [0, cds) = calldata, [cds, cds+0x37) = extraData
                // 36          | CALLDATASIZE          | cds 0 0 0 0             | [0, cds) = calldata, [cds, cds+0x37) = extraData
                // 61 extra    | PUSH2 extra           | extra cds 0 0 0 0       | [0, cds) = calldata, [cds, cds+0x37) = extraData
                mstore(
                    add(ptr, 0x15),
                    0x6037363936610000000000000000000000000000000000000000000000000000
                )
                mstore(add(ptr, 0x1b), shl(240, extraLength))

                // 01          | ADD                   | cds+extra 0 0 0 0       | [0, cds) = calldata, [cds, cds+0x37) = extraData
                // 3d          | RETURNDATASIZE        | 0 cds 0 0 0 0           | [0, cds) = calldata, [cds, cds+0x37) = extraData
                // 73 addr     | PUSH20 0x123…         | addr 0 cds 0 0 0 0      | [0, cds) = calldata, [cds, cds+0x37) = extraData
                mstore(
                    add(ptr, 0x1d),
                    0x013d730000000000000000000000000000000000000000000000000000000000
                )
                mstore(add(ptr, 0x20), shl(0x60, implementation))

                // 5a          | GAS                   | gas addr 0 cds 0 0 0 0  | [0, cds) = calldata, [cds, cds+0x37) = extraData
                // f4          | DELEGATECALL          | success 0 0             | [0, cds) = calldata, [cds, cds+0x37) = extraData
                // 3d          | RETURNDATASIZE        | rds success 0 0         | [0, cds) = calldata, [cds, cds+0x37) = extraData
                // 3d          | RETURNDATASIZE        | rds rds success 0 0     | [0, cds) = calldata, [cds, cds+0x37) = extraData
                // 93          | SWAP4                 | 0 rds success 0 rds     | [0, cds) = calldata, [cds, cds+0x37) = extraData
                // 80          | DUP1                  | 0 0 rds success 0 rds   | [0, cds) = calldata, [cds, cds+0x37) = extraData
                // 3e          | RETURNDATACOPY        | success 0 rds           | [0, rds) = return data (there might be some irrelevant leftovers in memory [rds, cds+0x37) when rds < cds+0x37)
                // 60 0x35     | PUSH1 0x35            | 0x35 sucess 0 rds       | [0, rds) = return data
                // 57          | JUMPI                 | 0 rds                   | [0, rds) = return data
                // fd          | REVERT                | –                       | [0, rds) = return data
                // 5b          | JUMPDEST              | 0 rds                   | [0, rds) = return data
                // f3          | RETURN                | –                       | [0, rds) = return data
                mstore(
                    add(ptr, 0x34),
                    0x5af43d3d93803e603557fd5bf300000000000000000000000000000000000000
                )
            }

            // -------------------------------------------------------------------------------------------------------------
            // APPENDED DATA (Accessible from extcodecopy)
            // (but also send as appended data to the delegatecall)
            // -------------------------------------------------------------------------------------------------------------

            extraLength -= 2;
            uint256 counter = extraLength;
            uint256 copyPtr = ptr + 0x41;
            // solhint-disable-next-line no-inline-assembly
            assembly {
                dataPtr := add(data, 32)
            }
            for (; counter >= 32; counter -= 32) {
                // solhint-disable-next-line no-inline-assembly
                assembly {
                    mstore(copyPtr, mload(dataPtr))
                }

                copyPtr += 32;
                dataPtr += 32;
            }
            uint256 mask = ~(256**(32 - counter) - 1);
            // solhint-disable-next-line no-inline-assembly
            assembly {
                mstore(copyPtr, and(mload(dataPtr), mask))
            }
            copyPtr += counter;
            // solhint-disable-next-line no-inline-assembly
            assembly {
                mstore(copyPtr, shl(240, extraLength))
            }
            // solhint-disable-next-line no-inline-assembly
            assembly {
                instance := create(0, ptr, creationSize)
            }
            if (instance == address(0)) {
                revert CreateFail();
            }
        }
    }
}

/// @notice ClubSig Factory.
contract ClubSigFactory is Multicall, ClubSig {
    /// -----------------------------------------------------------------------
    /// Library usage
    /// -----------------------------------------------------------------------
    
    using ClonesWithImmutableArgs for address;

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event SigDeployed(
        ClubSig indexed clubSig, 
        Club[] club_, 
        uint256 quorum, 
        bytes32 name, 
        bytes32 symbol, 
        bool paused,
        string baseURI
    );

    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    error NullDeploy();

    /// -----------------------------------------------------------------------
    /// Immutable parameters
    /// -----------------------------------------------------------------------

    ClubSig internal immutable clubMaster;

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor(ClubSig clubMaster_) {
        clubMaster = clubMaster_;
    }

    /// -----------------------------------------------------------------------
    /// Deployment
    /// -----------------------------------------------------------------------
    
    function deployClubSig(
        Club[] calldata club_,
        uint256 quorum_,
        bytes32 name_,
        bytes32 symbol_,
        bool paused_,
        string calldata baseURI_
    ) public payable virtual returns (ClubSig clubSig) {
        bytes memory data = abi.encodePacked(name_, symbol_);

        clubSig = ClubSig(address(clubMaster).clone(data));

        clubSig.init(
            club_,
            quorum_,
            paused_,
            baseURI_
        );

        emit SigDeployed(clubSig, club_, quorum_, name_, symbol_, paused_, baseURI_);
    }
}
