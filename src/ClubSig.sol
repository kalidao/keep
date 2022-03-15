// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {ClubNFT} from './ClubNFT.sol';

import {Multicall} from './utils/Multicall.sol';
import {NFTreceiver} from './utils/NFTreceiver.sol';

import {IClub} from './interfaces/IClub.sol';
import {IERC1271} from './interfaces/IERC1271.sol';
import {IERC20minimal} from './interfaces/IERC20minimal.sol';

import {FixedPointMathLib} from './libraries/FixedPointMathLib.sol';
import {SafeTransferTokenLib} from './libraries/SafeTransferTokenLib.sol';
import {URIbuilder} from './libraries/URIbuilder.sol';

/// @title ClubSig
/// @notice EIP-712-signed multi-signature contract with ragequit and NFT identifiers for signers
/// @author Modified from MultiSignatureWallet (https://github.com/SilentCicero/MultiSignatureWallet)
/// License-Identifier: MIT
/// and LilGnosis (https://github.com/m1guelpf/lil-web3/blob/main/src/LilGnosis.sol)
/// License-Identifier: AGPL-3.0-only
contract ClubSig is ClubNFT, Multicall, IClub {
    /// -----------------------------------------------------------------------
    /// Library Usage
    /// -----------------------------------------------------------------------
    using SafeTransferTokenLib for address;

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event Execute(address indexed to, uint256 value, bytes data);
    event Govern(Club[] club, bool[] mints, uint256 quorum);
    event GovernorFlipped(address indexed account);
    event DocsUpdated(string docs);
    event URIupdated(string uri);

    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    error Initialized();
    error SigsBounded();
    error WrongSigner();
    error NoArrayParity();
    error AssetOrder();

    /// -----------------------------------------------------------------------
    /// Club Storage
    /// -----------------------------------------------------------------------

    /// @dev initialized at `1` for cheaper first tx
    uint256 public nonce;
    /// @dev signature (NFT) threshold to execute tx
    uint256 public quorum;
    /// @dev metadata signifying club agreements
    string public docs;
    /// @dev optional metadata signifying club logo
    string public baseURI;
    /// @dev total signer units minted
    uint256 public totalSupply;
    /// @dev total ragequittable units minted
    uint256 public totalLoot;
    /// @dev ragequittable units per account
    mapping(address => uint256) public loot;
    /// @dev administrative account tracking
    mapping(address => bool) public governor;

    modifier OnlyClubOrGov {
        if (msg.sender != address(this) 
        && !governor[msg.sender]) revert Forbidden();
        _;
    }

    /// -----------------------------------------------------------------------
    /// EIP-712 Storage/Logic
    /// -----------------------------------------------------------------------

    uint256 internal INITIAL_CHAIN_ID;
    bytes32 internal INITIAL_DOMAIN_SEPARATOR;

    struct Signature {
	uint8 v;
	bytes32 r;
        bytes32 s;
    }

    function DOMAIN_SEPARATOR() internal view returns (bytes32) {
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
    /// Initializer
    /// -----------------------------------------------------------------------

    function init(
        Club[] calldata club_,
        uint256 quorum_,
        bool paused_,
        string calldata docs_,
        string calldata baseURI_
    ) external payable {
        if (nonce != 0) revert Initialized();

        ClubNFT._init(paused_);

        uint256 length = club_.length;

        if (quorum_ > length) revert SigsBounded();

        uint256 totalSupply_;
        uint256 totalLoot_;
        address prevAddr;

        for (uint256 i; i < length;) {
            // prevent null and duplicate signers
            if (prevAddr >= club_[i].signer) revert WrongSigner();
            prevAddr = club_[i].signer;

            _safeMint(club_[i].signer, club_[i].id);

            totalLoot_ += club_[i].loot;
            loot[club_[i].signer] = club_[i].loot;

            // cannot realistically overflow on human timescales
            unchecked {
                ++i;
                ++totalSupply_;
            }
        }

        totalSupply = totalSupply_;
        totalLoot = totalLoot_;

        nonce = 1;
        quorum = quorum_;
        docs = docs_;
        baseURI = baseURI_;

        INITIAL_CHAIN_ID = block.chainid;
        INITIAL_DOMAIN_SEPARATOR = _computeDomainSeparator();
    }

    /// -----------------------------------------------------------------------
    /// Metadata Logic
    /// -----------------------------------------------------------------------

    function tokenURI(uint256 id) external view returns (string memory) {
        bytes memory base = bytes(baseURI);

        if (base.length == 0) {
            address owner = ownerOf[id];
            uint256 lt = loot[owner];
            return URIbuilder._buildTokenURI(owner, lt, name());
        } else {
            return baseURI;
        }
    }

    /// -----------------------------------------------------------------------
    /// Operations
    /// -----------------------------------------------------------------------

    function execute(
        address to, 
        uint256 value, 
        bytes memory data, 
        bool deleg, 
        Signature[] calldata sigs
    ) external payable returns (bool success) {
        unchecked {
            bytes32 digest = keccak256(abi.encodePacked('\x19\x01', DOMAIN_SEPARATOR(),
                keccak256(abi.encode(keccak256(
                    'Exec(address to,uint256 value,bytes data,bool deleg,uint256 nonce)'),
                    // cannot realistically overflow on human timescales
                    to, value, data, deleg, ++nonce)))
                );

            address prevAddr;

            for (uint256 i; i < quorum; ++i) {
                address signer = ecrecover(digest, sigs[i].v, sigs[i].r, sigs[i].s);
                // check for conformant contract signature
                if (signer.code.length != 0 && IERC1271(signer).isValidSignature(
                        digest, abi.encodePacked(sigs[i].r, sigs[i].s, sigs[i].v)) != 0x1626ba7e // magic value
                    ) revert WrongSigner();
                // check for NFT balance and duplicates
                if (balanceOf[signer] == 0 || prevAddr >= signer) revert WrongSigner();
                prevAddr = signer;
            }
        }

        uint256 gasLeft = gasleft() - 2500;

        if (!deleg) {
            assembly {
                success := call(gasLeft, to, value, add(data, 0x20), mload(data), 0, 0)
            }
        } else { // delegate call
            assembly {
                success := delegatecall(gasLeft, to, add(data, 0x20), mload(data), 0, 0)
            }
        }

        emit Execute(to, value, data);
    }

    function govern(
        Club[] calldata club_,
        bool[] calldata mints_,
        uint256 quorum_
    ) external payable OnlyClubOrGov {
        uint256 length = club_.length;

        if (length != mints_.length) revert NoArrayParity();

        uint256 totalSupply_ = totalSupply;
        uint256 totalLoot_ = totalLoot;

        for (uint256 i; i < length;) {
            if (mints_[i]) {
                _safeMint(club_[i].signer, club_[i].id);
                // cannot realistically overflow on human timescales
                unchecked {
                    ++totalSupply_;
                }
            } else {
                _burn(club_[i].id);
                // cannot underflow because ownership is checked in burn()
                unchecked {
                    --totalSupply_;
                }
            }
            if (club_[i].loot != 0) {
                totalLoot_ += club_[i].loot;
                // cannot overflow because the sum of all user
                // balances can't exceed the max uint256 value
                unchecked {
                    loot[club_[i].signer] += club_[i].loot;
                }
            }
            // cannot realistically overflow on human timescales
            unchecked {
                ++i;
            }
        }

        if (totalLoot_ != 0) totalLoot = totalLoot_;
        // note: also make sure that signers don't concentrate NFTs,
        // since this could cause issues in reaching quorum
        if (quorum_ > totalSupply_) revert SigsBounded();

        totalSupply = totalSupply_;
        quorum = quorum_;

        emit Govern(club_, mints_, quorum_);
    }

    function governorExecute(
        address to, 
        uint256 value, 
        bytes memory data, 
        bool deleg
    ) external payable returns (bool success) {
        if (!governor[msg.sender]) revert Forbidden();

        uint256 gasLeft = gasleft() - 2500;

        if (!deleg) {
            assembly {
                success := call(gasLeft, to, value, add(data, 0x20), mload(data), 0, 0)
            }
        } else { // delegate call
            assembly {
                success := delegatecall(gasLeft, to, add(data, 0x20), mload(data), 0, 0)
            }
        }

        emit Execute(to, value, data);
    }

    function flipGovernor(address account) external payable OnlyClubOrGov {
        governor[account] = !governor[account];
        emit GovernorFlipped(account);
    }

    function flipPause() external payable OnlyClubOrGov {
        ClubNFT._flipPause();
    }

    function updateDocs(string calldata docs_) external payable OnlyClubOrGov {
        docs = docs_;
        emit DocsUpdated(docs_);
    }

    function updateURI(string calldata baseURI_) external payable OnlyClubOrGov {
        baseURI = baseURI_;
        emit URIupdated(baseURI_);
    }

    /// -----------------------------------------------------------------------
    /// Asset Management
    /// -----------------------------------------------------------------------

    receive() external payable {}

    function ragequit(address[] calldata assets, uint256 lootToBurn) external payable {
        uint256 lootTotal = totalLoot;
        loot[msg.sender] -= lootToBurn;
        // cannot underflow because balance is checked above
        unchecked {
            totalLoot -= lootToBurn;
        }

        address prevAddr;

        for (uint256 i; i < assets.length;) {
            // prevent null and duplicate assets
            if (prevAddr >= assets[i]) revert AssetOrder();
            prevAddr = assets[i];

            // calculate fair share of given assets for redemption
            uint256 amountToRedeem = FixedPointMathLib.mulDivDown(
                lootToBurn, 
                IERC20minimal(assets[i]).balanceOf(address(this)), 
                lootTotal
            );
            
            // transfer to redeemer
            if (amountToRedeem != 0) assets[i]._safeTransfer(msg.sender, amountToRedeem);
            // cannot realistically overflow on human timescales
            unchecked {
                ++i;
            }
        }
    }
}
