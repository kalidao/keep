// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity >=0.8.4;

import './ClubNFT.sol';
import './libraries/Base64.sol';
import './libraries/SafeTransferTokenLib.sol';
import './utils/Multicall.sol';
import './utils/NFTreceiver.sol';
import './interfaces/IERC20minimal.sol';
import './interfaces/IERC1271.sol';

/// @title ClubSig
/// @notice EIP-712-signed multi-signature contract with ragequit and NFT identifiers for signers
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
    event GovernorFlipped(address indexed account);
    event URIupdated(string uri);

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
    /// @dev last daily allowance claim
    mapping(address => uint256) public lastClaim;
    /// @dev administrative account tracking
    mapping(address => bool) public governor;

    struct Club {
        address signer;
        uint256 id;
        uint256 loot;
    }

    struct Call {
        address target;
        uint256 value;
        bytes payload;
        bool call; // if not, delegate call
    }

    /// -----------------------------------------------------------------------
    /// Initializer
    /// -----------------------------------------------------------------------

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
                    call.target, call.value, call.payload, call.call, nonce++)))
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
       
        if (call.call) {
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

        uint256 totalSupply_ = totalSupply;
        uint256 lootSupply;
        for (uint256 i = 0; i < length;) {
            if (mints_[i]) {
                _safeMint(club_[i].signer, club_[i].id);

                // cannot realistically overflow on human timescales
                unchecked {
                    totalSupply_++;
                }
            } else {
                _burn(club_[i].id);
                totalSupply_--;
            }
            if (club_[i].loot != 0) {
                loot[club_[i].signer] += club_[i].loot;
                lootSupply += club_[i].loot;
            }

            // cannot realistically overflow on human timescales
            unchecked {
                i++;
            }
        }

        if (lootSupply != 0) totalLoot += lootSupply;
        // note: also make sure that signers don't concentrate NFTs,
        // since this could cause issues in reaching quorum
        if (quorum_ > totalSupply_) revert SigBounds();

        totalSupply = totalSupply_;
        quorum = quorum_;

        emit Govern(club_, mints_, quorum_);
    }

    function governorExecute(Call calldata call) public payable returns (bool success, bytes memory result) {
        if (!governor[msg.sender]) revert Forbidden();

        if (call.call) {
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

        emit GovernorFlipped(account);
    }

    function flipPause() public payable {
        if (msg.sender != address(this) && !governor[msg.sender]) revert Forbidden();

        ClubNFT._flipPause();
    }

    function updateURI(string calldata baseURI_) public payable {
        if (msg.sender != address(this) && !governor[msg.sender]) revert Forbidden();

        baseURI = baseURI_;

        emit URIupdated(baseURI_);
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
