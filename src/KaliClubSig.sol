// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {ILoot} from './interfaces/ILoot.sol';
import {IMember} from './interfaces/IMember.sol';
import {IERC1271} from './interfaces/IERC1271.sol';

import {FixedPointMathLib} from './libraries/FixedPointMathLib.sol';
import {SafeTransferLib} from './libraries/SafeTransferLib.sol';

import {ClubNFT} from './ClubNFT.sol';
import {Multicall} from './utils/Multicall.sol';
import {NFTreceiver} from './utils/NFTreceiver.sol';

/// @title Kali ClubSig
/// @notice EIP-712-signed multi-signature contract with ragequit and NFT identifiers for signers
/// @author Modified from MultiSignatureWallet (https://github.com/SilentCicero/MultiSignatureWallet)
/// License-Identifier: MIT
/// and LilGnosis (https://github.com/m1guelpf/lil-web3/blob/main/src/LilGnosis.sol)
/// License-Identifier: AGPL-3.0-only
/// @dev Lightweight implementation of Moloch v3 
/// (https://github.com/Moloch-Mystics/Baal/blob/main/contracts/Baal.sol)
/// License-Identifier: UNLICENSED

struct Call {
    address to;
    uint256 value;
    bytes data;
    bool deleg;
}

struct Signature {
    uint8 v;
    bytes32 r;
    bytes32 s;
}

contract KaliClubSig is IMember, ClubNFT, Multicall {
    /// -----------------------------------------------------------------------
    /// Library Usage
    /// -----------------------------------------------------------------------

    using SafeTransferLib for address;

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event Execute(
        address indexed to, 
        uint256 value, 
        bytes data
    );
    event Govern(
        Member[] members, 
        bool[] mints, 
        uint256 quorum
    );
    event GovernorSet(address indexed account, bool approved);
    event RedemptionStartSet(uint256 redemptionStart);
    event URIset(string uri);

    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    error AlreadyInitialized();
    error QuorumExceedsSigs();
    error BadSigner();
    error ExecuteFailed();
    error NoArrayParity();
    error NoRedemptionYet();
    error WrongAssetOrder();

    /// -----------------------------------------------------------------------
    /// Club Storage/Logic
    /// -----------------------------------------------------------------------

    /// @dev ETH reference for redemptions
    address private constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    /// @dev State change tracker - initialized at `1` for cheaper first tx
    uint256 public nonce;
    /// @dev Signature (NFT) threshold to execute tx
    uint256 public quorum;
    /// @dev Starting period for club redemptions
    uint256 public redemptionStart;
    /// @dev Total signer units minted
    uint256 public totalSupply;
    /// @dev Metadata signifying club
    string public tokenURI;

    /// @dev Administrative account tracking
    mapping(address => bool) public governor;

    /// @dev Access control for this contract and governors
    modifier onlyClubOrGov() {
        if (msg.sender != address(this) && !governor[msg.sender])
            revert Forbidden();
        _;
    }
    
    /// @dev Access control for this contract and governors
    function loot() public pure returns (ILoot lootAddr) {
        uint256 offset = _getImmutableArgsOffset();
        
        assembly {
            lootAddr := shr(0x60, calldataload(add(offset, 0x40)))
        }
    }

    /// -----------------------------------------------------------------------
    /// EIP-712 Storage/Logic
    /// -----------------------------------------------------------------------

    bytes32 private INITIAL_DOMAIN_SEPARATOR;

    function INITIAL_CHAIN_ID() private pure returns (uint256 chainId) {
        uint256 offset = _getImmutableArgsOffset();
        
        assembly {
            chainId := shr(0xc0, calldataload(add(offset, 0x54)))
        }
    }

    function DOMAIN_SEPARATOR() public view returns (bytes32) {
        return
            block.chainid == INITIAL_CHAIN_ID()
                ? INITIAL_DOMAIN_SEPARATOR
                : _computeDomainSeparator();
    }

    function _computeDomainSeparator() private view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    keccak256(
                        'EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'
                    ),
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
        Call[] calldata calls_,
        Member[] calldata members_,
        uint256 quorum_,
        uint256 redemptionStart_,
        bool signerPaused_,
        string calldata tokenURI_
    ) external payable {
        if (nonce != 0) revert AlreadyInitialized();
        assembly {
            if iszero(quorum_) {
                revert(0, 0)
            }
        }
        if (quorum_ > members_.length) revert QuorumExceedsSigs();

        if (calls_.length != 0) {
            for (uint256 i; i < calls_.length; ) {
                _execute(calls_[i].to, calls_[i].value, calls_[i].data, calls_[i].deleg);
                // cannot realistically overflow
                unchecked {
                    ++i;
                }
            }
        }

        address prevAddr;
        uint256 totalSupply_;

        for (uint256 i; i < members_.length; ) {
            // prevent null and duplicate signers
            if (prevAddr >= members_[i].signer) revert BadSigner();
            prevAddr = members_[i].signer;

            _safeMint(members_[i].signer, members_[i].id);
            // cannot realistically overflow
            unchecked {
                ++totalSupply_;
                ++i;
            }
        }

        ClubNFT._setPause(signerPaused_);

        nonce = 1;
        quorum = quorum_;
        redemptionStart = redemptionStart_;
        totalSupply = totalSupply_;
        tokenURI = tokenURI_;
        INITIAL_DOMAIN_SEPARATOR = _computeDomainSeparator();
    }

    /// -----------------------------------------------------------------------
    /// Operations
    /// -----------------------------------------------------------------------

    function getDigest(
        address to,
        uint256 value,
        bytes calldata data,
        bool deleg,
        uint256 tx_nonce
    ) public view returns (bytes32) {
        // exposed to precompute digest when signing
        return 
            keccak256(
                abi.encodePacked(
                    '\x19\x01',
                    DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            keccak256(
                                'Exec(address to,uint256 value,bytes data,bool deleg,uint256 nonce)'
                            ),
                            to,
                            value,
                            data,
                            deleg,
                            tx_nonce
                        )
                    )
                )
            );
    }
    
    /// @notice Execute transaction from club with signatures
    /// @param to Address to send transaction to
    /// @param value Amount of ETH to send in transaction
    /// @param data Payload to send in transaction
    /// @param deleg Whether or not to perform delegatecall
    /// @param sigs Array of signatures from NFT sorted in ascending order by addresses
    /// @dev Make sure signatures are sorted in ascending order - otherwise verification will fail
    /// @return Fetches whether transaction succeeded
    function execute(
        address to,
        uint256 value,
        bytes calldata data,
        bool deleg,
        Signature[] calldata sigs
    ) external payable returns (bool success) {
        // begin signature validation with payload hash
        bytes32 digest = getDigest(to, value, data, deleg, nonce);
        // starting from zero address in loop to ensure addresses are ascending
        address prevAddr;
        // validation is length of quorum threshold 
        uint256 quorum_ = quorum;
        for (uint256 i; i < quorum_; ) {
            address signer = ecrecover(
                digest,
                sigs[i].v,
                sigs[i].r,
                sigs[i].s
            );
            // check for conformant contract signature using EIP-1271
            // - branching on whether signer is contract
            if (signer.code.length != 0) {
                if (
                    IERC1271(signer).isValidSignature(
                        digest,
                        abi.encodePacked(sigs[i].r, sigs[i].s, sigs[i].v)
                    ) != IERC1271.isValidSignature.selector
                ) revert BadSigner();
            }
            // check for NFT balance and duplicates
            if (balanceOf[signer] == 0 || prevAddr >= signer)
                revert BadSigner();
            // set prevAddr to signer for next iteration until quorum
            prevAddr = signer;
            // cannot realistically overflow
            unchecked {
                ++i;
            }
        }
        
        success = _execute(to, value, data, deleg);
    }
    
    /// @notice Execute array of transactions from club as result of execute() or as governor
    /// @param calls Arrays of `to, value, data, deleg` for transactions
    /// @return Fetches whether transactions succeeded
    function batchExecute(Call[] calldata calls) external payable onlyClubOrGov returns (bool[] memory successes) {
        successes = new bool[](calls.length);

        for (uint256 i; i < calls.length; ) {
            successes[i] = _execute(calls[i].to, calls[i].value, calls[i].data, calls[i].deleg);
            // cannot realistically overflow
            unchecked {
                ++i;
            }
        }
    }

    function _execute(
        address to, 
        uint256 value, 
        bytes memory data,
        bool deleg
    ) private returns (bool success) {
        if (!deleg) {
            // regular 
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
            // delegate
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
        if (!success) revert ExecuteFailed();
        // cannot realistically overflow
        unchecked {
            ++nonce;
        }

        emit Execute(to, value, data);
    }
    
    /// @notice Update club configurations for membership and quorum
    /// @param members_ Arrays of `signer, id, loot` for membership
    /// @param mints_ Boolean array that determines whether mint or burn
    /// @param quorum_ Signature threshold to execute transactions
    function govern(
        Member[] calldata members_,
        bool[] calldata mints_,
        uint256 quorum_
    ) external payable onlyClubOrGov {
        if (members_.length != mints_.length) revert NoArrayParity();
        assembly {
            if iszero(quorum_) {
                revert(0, 0)
            }
        }

        uint256 totalSupply_ = totalSupply;
        // cannot realistically overflow, and
        // cannot underflow because ownership is checked in burn()
        unchecked {
            for (uint256 i; i < members_.length; ++i) {
                if (mints_[i]) {
                    // mint NFT, update supply
                    _safeMint(members_[i].signer, members_[i].id);
                    ++totalSupply_;
                    // if loot amount, mint loot
                    if (members_[i].loot != 0) loot().mintShares(members_[i].signer, members_[i].loot);
                } else {
                    // burn NFT, update supply
                    _burn(members_[i].id);
                    --totalSupply_;
                    // if loot amount, burn loot
                    if (members_[i].loot != 0) loot().burnShares(members_[i].signer, members_[i].loot);
                }
            }
        }
        // note: also make sure that signers don't concentrate NFTs,
        // since this could cause issues in reaching quorum
        if (quorum_ > totalSupply_) revert QuorumExceedsSigs();

        quorum = quorum_;
        totalSupply = totalSupply_;

        emit Govern(members_, mints_, quorum_);
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
        loot().setPause(paused_);
    }

    function setSignerPause(bool paused_) external payable onlyClubOrGov {
        ClubNFT._setPause(paused_);
    }

    function setURI(string calldata tokenURI_) external payable onlyClubOrGov {
        tokenURI = tokenURI_;
        emit URIset(tokenURI_);
    }

    /// -----------------------------------------------------------------------
    /// Redemptions
    /// -----------------------------------------------------------------------
    
    /// @notice Redemption option for `loot` holders
    /// @param assets Array of assets to redeem out
    /// @param lootToBurn Amount of `loot` to burn
    /// @dev Redemption is only available for ETH and ERC-20
    /// - NFTs will need to be liquidated or fractionalized
    function ragequit(address[] calldata assets, uint256 lootToBurn)
        external
        payable
    {
        if (block.timestamp < redemptionStart) revert NoRedemptionYet();

        uint256 lootTotal = loot().totalSupply();

        loot().burnShares(msg.sender, lootToBurn);
        
        address prevAddr;

        for (uint256 i; i < assets.length; ) {
            // prevent null and duplicate assets
            if (prevAddr >= assets[i]) revert WrongAssetOrder();
            prevAddr = assets[i];
            // calculate fair share of given assets for redemption
            uint256 amountToRedeem = FixedPointMathLib._mulDivDown(
                lootToBurn,
                assets[i] == ETH
                    ? address(this).balance
                    : ILoot(assets[i]).balanceOf(address(this)),
                lootTotal
            );
            // transfer to redeemer
            if (amountToRedeem != 0)
                assets[i] == ETH
                    ? msg.sender._safeTransferETH(amountToRedeem)
                    : assets[i]._safeTransfer(msg.sender, amountToRedeem);
            // cannot realistically overflow
            unchecked {
                ++i;
            }
        }
    }
}
