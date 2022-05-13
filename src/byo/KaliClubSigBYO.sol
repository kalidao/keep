// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {Multicall} from '../utils/Multicall.sol';
import {NFTreceiver} from '../utils/NFTreceiver.sol';

import {IClubLoot} from '../interfaces/IClubLoot.sol';
import {IERC721minimal} from '../interfaces/IERC721minimal.sol';
import {IERC1271} from '../interfaces/IERC1271.sol';

import {FixedPointMathLib} from '../libraries/FixedPointMathLib.sol';
import {SafeTransferLib} from '../libraries/SafeTransferLib.sol';

/// @title Kali ClubSig
/// @notice EIP-712-signed multi-signature contract with ragequit and (BYO) NFT identifiers for signers
/// @author Modified from MultiSignatureWallet (https://github.com/SilentCicero/MultiSignatureWallet)
/// License-Identifier: MIT
/// and LilGnosis (https://github.com/m1guelpf/lil-web3/blob/main/src/LilGnosis.sol)
/// License-Identifier: AGPL-3.0-only

struct Signature {
    uint8 v;
    bytes32 r;
    bytes32 s;
}

contract KaliClubSigBYO is Multicall {
    /// -----------------------------------------------------------------------
    /// Library Usage
    /// -----------------------------------------------------------------------

    using SafeTransferLib for address;

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event Execute(address indexed to, uint256 value, bytes data);
    event DocsSet(string docs);
    event GovernorSet(address indexed account, bool approved);
    event QuorumSet(uint256 quorum);
    event RedemptionStartSet(uint256 redemptionStart);

    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    error Forbidden();
    error AlreadyInitialized();
    error WrongSigner();
    error ExecuteFailed();
    error RedemptionTooEarly();
    error WrongAssetOrder();

    /// -----------------------------------------------------------------------
    /// Club Storage
    /// -----------------------------------------------------------------------

    /// @dev ETH reference for redemptions
    address private constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    /// @dev initialized at `1` for cheaper first tx
    uint256 public nonce;
    /// @dev signature (NFT) threshold to execute tx
    uint256 public quorum;
    /// @dev starting period for club redemptions
    uint256 public redemptionStart;
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

    function DOMAIN_SEPARATOR() public view returns (bytes32) {
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
    /// Metadata Logic
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

    function clubNFT() public pure returns (IERC721minimal nftAddr) {
        uint256 offset;

        assembly {
            offset := sub(
                calldatasize(),
                add(shr(240, calldataload(sub(calldatasize(), 2))), 2)
            )
        }
        assembly {
            nftAddr := shr(0x60, calldataload(add(offset, 0x40)))
        }
    }

    function loot() public pure returns (IClubLoot lootAddr) {
        uint256 offset;

        assembly {
            offset := sub(
                calldatasize(),
                add(shr(240, calldataload(sub(calldatasize(), 2))), 2)
            )
        }
        assembly {
            lootAddr := shr(0x60, calldataload(add(offset, 0x60)))
        }
    }

    /// -----------------------------------------------------------------------
    /// Initializer
    /// -----------------------------------------------------------------------

    function init(
        uint256 quorum_,
        uint256 redemptionStart_,
        string calldata docs_
    ) external payable {
        if (nonce != 0) revert AlreadyInitialized();
        assembly {
            if iszero(quorum_) {
                revert(0, 0)
            }
        }

        nonce = 1;
        quorum = quorum_;
        redemptionStart = redemptionStart_;
        docs = docs_;
        INITIAL_CHAIN_ID = block.chainid;
        INITIAL_DOMAIN_SEPARATOR = _computeDomainSeparator();
    }

    /// -----------------------------------------------------------------------
    /// Operations
    /// -----------------------------------------------------------------------

    function getDigest(
        address to,
        uint256 value,
        bytes memory data,
        bool deleg,
        uint256 tx_nonce
    ) public view returns (bytes32 digest) {
        // exposed for the user to precompute a digest when signing
        digest = keccak256(
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

    function execute(
        address to,
        uint256 value,
        bytes memory data,
        bool deleg,
        Signature[] calldata sigs
    ) external payable returns (bool success) {
        // governor has admin privileges to execute without quorum
        if (!governor[msg.sender]) {
            bytes32 digest = getDigest(to, value, data, deleg, nonce);

            // starting from the zero address here to ensure that all addresses are greater than
            address prevAddr;

            for (uint256 i; i < quorum; ) {
                address signer = ecrecover(
                    digest,
                    sigs[i].v,
                    sigs[i].r,
                    sigs[i].s
                );
                // check for conformant contract signature using EIP-1271
                // - branching on whether signer address is an EOA or a contract
                if (
                    signer.code.length != 0 &&
                    IERC1271(signer).isValidSignature(
                        digest,
                        abi.encodePacked(sigs[i].r, sigs[i].s, sigs[i].v)
                    ) !=
                    0x1626ba7e // magic value
                ) revert WrongSigner();
                // check for NFT balance and duplicates
                if (clubNFT().balanceOf(signer) == 0 || prevAddr >= signer)
                    revert WrongSigner();
                // set prevAddr to signer for the next iteration until we've reached quorum
                prevAddr = signer;
                // cannot realistically overflow on human timescales
                unchecked {
                    ++i;
                }
            }
        }
        if (!deleg) {
            // if this is not a delegated call
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
        if (!success) revert ExecuteFailed();
        // cannot realistically overflow on human timescales
        unchecked {
            ++nonce;
        }

        emit Execute(to, value, data);
    }

    function setDocs(string calldata docs_) external payable onlyClubOrGov {
        docs = docs_;
        emit DocsSet(docs_);
    }

    function setGovernor(address account, bool approved)
        external
        payable
        onlyClubOrGov
    {
        governor[account] = approved;
        emit GovernorSet(account, approved);
    }

    function setLootPause(bool paused_) external payable onlyClubOrGov {
        loot().setPause(paused_);
    }

    function setQuorum(uint256 quorum_) external payable onlyClubOrGov {
        assembly {
            if iszero(quorum_) {
                revert(0, 0)
            }
        }

        quorum = quorum_;
        emit QuorumSet(quorum_);
    }

    function setRedemptionStart(uint256 redemptionStart_)
        external
        payable
        onlyClubOrGov
    {
        redemptionStart = redemptionStart_;
        emit RedemptionStartSet(redemptionStart_);
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
        if (block.timestamp < redemptionStart) revert RedemptionTooEarly();

        uint256 lootTotal = loot().totalSupply();

        address prevAddr;

        for (uint256 i; i < assets.length; ) {
            // prevent null and duplicate assets
            if (prevAddr >= assets[i]) revert WrongAssetOrder();
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

        loot().burnShares(msg.sender, lootToBurn);
    }
}
