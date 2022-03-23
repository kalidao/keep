// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {ClubNFT} from "./ClubNFT.sol";

import {Multicall} from "./utils/Multicall.sol";
import {NFTreceiver} from "./utils/NFTreceiver.sol";

import {IClub} from "./interfaces/IClub.sol";
import {IClubLoot} from "./interfaces/IClubLoot.sol";
import {IERC1271} from "./interfaces/IERC1271.sol";

import {FixedPointMathLib} from "./libraries/FixedPointMathLib.sol";
import {SafeTransferLib} from "./libraries/SafeTransferLib.sol";
import {ClubURIbuilder} from "./libraries/ClubURIbuilder.sol";

/// @title Kali ClubSig
/// @notice EIP-712-signed multi-signature contract with ragequit and NFT identifiers for signers
/// @author Modified from MultiSignatureWallet (https://github.com/SilentCicero/MultiSignatureWallet)
/// License-Identifier: MIT
/// and LilGnosis (https://github.com/m1guelpf/lil-web3/blob/main/src/LilGnosis.sol)
/// License-Identifier: AGPL-3.0-only

struct Signature {
    uint8 v;
    bytes32 r;
    bytes32 s;
}

contract KaliClubSig is ClubNFT, Multicall, IClub {
    /// -----------------------------------------------------------------------
    /// Library Usage
    /// -----------------------------------------------------------------------

    using SafeTransferLib for address;

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event Execute(address indexed to, uint256 value, bytes data);
    event Govern(Club[] club, bool[] mints, uint256 quorum);
    event GovernorSet(address indexed account, bool approved);
    event RedemptionStartSet(uint256 redemptionStart);
    event DocsUpdated(string docs);
    event URIupdated(string uri);

    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    error Initialized();
    error SigsBounded();
    error WrongSigner();
    error NoArrayParity();
    error RedemptionEarly();
    error AssetOrder();
    error ExecuteError();

    /// -----------------------------------------------------------------------
    /// Club Storage
    /// -----------------------------------------------------------------------

    /// @dev ETH reference for redemptions
    address private constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    /// @dev ERC-20 token for capital management
    IClubLoot public loot;
    /// @dev initialized at `1` for cheaper first tx
    uint256 public nonce;
    /// @dev signature (NFT) threshold to execute tx
    uint256 public quorum;
    /// @dev starting period for club redemptions
    uint256 public redemptionStart;
    /// @dev total signer units minted
    uint256 public totalSupply;
    /// @dev optional metadata signifying club
    string public baseURI;
    /// @dev metadata signifying club agreements
    string public docs;

    /// @dev administrative account tracking
    mapping(address => bool) public governor;

    /// @dev access control for this contract and governors
    modifier onlyClubOrGov() {
        if (msg.sender != address(this) && !governor[msg.sender])
            revert Forbidden();
        _;
    }

    /// -----------------------------------------------------------------------
    /// EIP-712 Storage/Logic
    /// -----------------------------------------------------------------------

    uint256 private INITIAL_CHAIN_ID;
    bytes32 private INITIAL_DOMAIN_SEPARATOR;

    function DOMAIN_SEPARATOR() private view returns (bytes32) {
        return
            block.chainid == INITIAL_CHAIN_ID
                ? INITIAL_DOMAIN_SEPARATOR
                : _computeDomainSeparator();
    }

    function _computeDomainSeparator() private view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    keccak256(
                        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                    ),
                    keccak256(bytes(name())),
                    keccak256("1"),
                    block.chainid,
                    address(this)
                )
            );
    }

    /// -----------------------------------------------------------------------
    /// Metadata Logic
    /// -----------------------------------------------------------------------

    function tokenURI(uint256 id) external view returns (string memory) {
        bytes memory base = bytes(baseURI);

        if (base.length == 0) {
            address owner = ownerOf[id];
            uint256 lt = loot.balanceOf(owner) / 1e18;
            return ClubURIbuilder._buildTokenURI(name(), symbol(), owner, lt);
        } else {
            return baseURI;
        }
    }

    /// -----------------------------------------------------------------------
    /// Initializer
    /// -----------------------------------------------------------------------

    function init(
        address loot_,
        Club[] calldata club_,
        uint256 quorum_,
        uint256 redemptionStart_,
        bool signerPaused_,
        string calldata baseURI_,
        string calldata docs_
    ) external payable {
        if (nonce != 0) revert Initialized();

        uint256 length = club_.length;

        if (quorum_ > length) revert SigsBounded();

        ClubNFT._init(signerPaused_);

        address prevAddr;
        uint256 totalSupply_;

        for (uint256 i; i < length; ) {
            // prevent null and duplicate signers
            if (prevAddr >= club_[i].signer) revert WrongSigner();
            prevAddr = club_[i].signer;

            _safeMint(club_[i].signer, club_[i].id);
            // cannot realistically overflow on human timescales
            unchecked {
                ++totalSupply_;
                ++i;
            }
        }

        loot = IClubLoot(loot_);
        nonce = 1;
        quorum = quorum_;
        redemptionStart = redemptionStart_;
        totalSupply = totalSupply_;
        baseURI = baseURI_;
        docs = docs_;
        INITIAL_CHAIN_ID = block.chainid;
        INITIAL_DOMAIN_SEPARATOR = _computeDomainSeparator();
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
        // Governor has admin privileges to execute without quorum.
        // TODO(This entire check could/should be a modifier which can be applied to this and potentially govern)
        if (!governor[msg.sender]) {
            // cannot realistically overflow on human timescales
            unchecked {
                // TODO(Potential reentrancy bug here incrementing nonce before external calls)
                // Consider intermediary storage on the stack and update after external calls
                bytes32 digest = keccak256(
                    abi.encodePacked(
                        "\x19\x01",
                        DOMAIN_SEPARATOR(),
                        keccak256(
                            abi.encode(
                                keccak256(
                                    "Exec(address to,uint256 value,bytes data,bool deleg,uint256 nonce)"
                                ),
                                to,
                                value,
                                data,
                                deleg,
                                ++nonce
                            )
                        )
                    )
                );

                // Starting from the zero address here to ensure that all addresses are greater than
                address prevAddr;

                // TODO(We assume here that the signers are sorted in the frontend?)
                for (uint256 i; i < quorum; ++i) {
                    address signer = ecrecover(
                        digest,
                        sigs[i].v,
                        sigs[i].r,
                        sigs[i].s
                    );
                    // check for conformant contract signature using EIP-1271
                    // branching on if the signer address is an EOA or a contract
                    if (
                        signer.code.length != 0 &&
                        IERC1271(signer).isValidSignature(
                            digest,
                            abi.encodePacked(sigs[i].r, sigs[i].s, sigs[i].v)
                        ) !=
                        0x1626ba7e // magic value
                    ) revert WrongSigner();
                    // check for NFT balance and duplicates
                    if (balanceOf[signer] == 0 || prevAddr >= signer)
                        revert WrongSigner();
                    // Set prevAddr to signer for the next iteration until we've reached quorum
                    prevAddr = signer;
                }
            }
        }

        // We have quorum or a call by a governor here
        // TODO(Support multicall here?)
        // A single execute could support chaining transactions like a molochdao
        // TODO(We throw away the return data here, there might be reason to parse the return values or pass them)
        // to later calls
        // https://gist.github.com/0xAlcibiades/4faf1601635eba8da17bdd3dd1c70692#file-multicall-sol-L171
        // food for thought.

        if (!deleg) {
            // If this is not a delegated call
            assembly {
                success := call(
                    gas(),
                    to,
                    value,
                    add(data, 0x20),
                    mload(data),
                    0,
                    0
                )
            }
        } else {
            // delegate call
            assembly {
                success := delegatecall(
                    gas(),
                    to,
                    add(data, 0x20),
                    mload(data),
                    0,
                    0
                )
            }
        }

        if (!success) revert ExecuteError();

        emit Execute(to, value, data);
    }

    // TODO(Multicall inheritance here is un-permissioned)

    // TODO(Should this be external, or public?)
    function govern(
        Club[] calldata club_,
        bool[] calldata mints_,
        uint256 quorum_
    ) external payable onlyClubOrGov {
        uint256 length = club_.length;

        if (length != mints_.length) revert NoArrayParity();

        uint256 totalSupply_ = totalSupply;
        // cannot realistically overflow on human timescales, and
        // cannot underflow because ownership is checked in burn()
        unchecked {
            for (uint256 i; i < length; ++i) {
                if (mints_[i]) {
                    _safeMint(club_[i].signer, club_[i].id);
                    ++totalSupply_;
                } else {
                    _burn(club_[i].id);
                    --totalSupply_;
                }
                if (club_[i].loot != 0) {
                    loot.mint(club_[i].signer, club_[i].loot);
                }
            }
        }
        // note: also make sure that signers don't concentrate NFTs,
        // since this could cause issues in reaching quorum
        if (quorum_ > totalSupply_) revert SigsBounded();

        quorum = quorum_;
        totalSupply = totalSupply_;

        emit Govern(club_, mints_, quorum_);
    }

    function setGovernor(address account, bool approved)
        external
        payable
        onlyClubOrGov
    {
        governor[account] = approved;
        emit GovernorSet(account, approved);
    }

    function setRedemptionStart(uint256 redemptionStart_)
        external
        payable
        onlyClubOrGov
    {
        redemptionStart = redemptionStart_;
        emit RedemptionStartSet(redemptionStart_);
    }

    function setLootPause(bool paused_) external payable onlyClubOrGov {
        loot.setPause(paused_);
    }

    function setSignerPause(bool paused_) external payable onlyClubOrGov {
        ClubNFT._setPause(paused_);
    }

    function updateDocs(string calldata docs_) external payable onlyClubOrGov {
        docs = docs_;
        emit DocsUpdated(docs_);
    }

    function updateURI(string calldata baseURI_)
        external
        payable
        onlyClubOrGov
    {
        baseURI = baseURI_;
        emit URIupdated(baseURI_);
    }

    /// -----------------------------------------------------------------------
    /// Asset Management
    /// -----------------------------------------------------------------------

    fallback() external payable {}

    receive() external payable {}

    /// @dev redemption is only available for ETH and ERC-20
    /// - NFTs will need to be liquidated or fractionalized
    function ragequit(address[] calldata assets, uint256 lootToBurn)
        external
        payable
    {
        if (block.timestamp < redemptionStart) revert RedemptionEarly();

        uint256 lootTotal = loot.totalSupply();

        address prevAddr;

        for (uint256 i; i < assets.length; ) {
            // prevent null and duplicate assets
            if (prevAddr >= assets[i]) revert AssetOrder();
            prevAddr = assets[i];
            // calculate fair share of given assets for redemption
            uint256 amountToRedeem = FixedPointMathLib.mulDivDown(
                lootToBurn,
                assets[i] == ETH
                    ? address(this).balance
                    : IClubLoot(assets[i]).balanceOf(address(this)),
                lootTotal
            );
            // transfer to redeemer
            if (amountToRedeem != 0)
                assets[i] == ETH
                    ? msg.sender._safeTransferETH(amountToRedeem)
                    : assets[i]._safeTransfer(msg.sender, amountToRedeem);
            // cannot realistically overflow on human timescales
            unchecked {
                ++i;
            }
        }

        loot.govBurn(msg.sender, lootToBurn);
    }
}
