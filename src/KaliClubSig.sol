// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {IMember} from './interfaces/IMember.sol';
import {IERC1271} from './interfaces/IERC1271.sol';

import {ClubNFT} from './ClubNFT.sol';
import {Multicall} from './utils/Multicall.sol';
import {NFTreceiver} from './utils/NFTreceiver.sol';

/// @title Kali ClubSig
/// @notice EIP-712-signed multi-signature contract with NFT identifiers for signers
/// @author Modified from MultiSignatureWallet (https://github.com/SilentCicero/MultiSignatureWallet)
/// License-Identifier: MIT
/// and LilGnosis (https://github.com/m1guelpf/lil-web3/blob/main/src/LilGnosis.sol)
/// License-Identifier: AGPL-3.0-only
/// @dev Lightweight implementation of Moloch v3 
/// (https://github.com/Moloch-Mystics/Baal/blob/main/contracts/Baal.sol)
/// License-Identifier: UNLICENSED

enum Operation {
    call,
    delegateCall,
    create,
    create2
}

struct Call {
    Operation op;
    address to;
    uint256 value;
    bytes data;
}

struct Signature {
    uint8 v;
    bytes32 r;
    bytes32 s;
}

contract KaliClubSig is IMember, ClubNFT, Multicall, NFTreceiver {
    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event Execute(
        address indexed to, 
        uint256 value, 
        bytes data
    );

    event Govern(Member[] members, uint256 quorum);

    event GovernorSet(address indexed account, bool approved);

    event URIset(string baseURI);

    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    error AlreadyInit();

    error QuorumOverSigs();

    error InvalidSig();

    error ExecuteFailed();

    /// -----------------------------------------------------------------------
    /// Club Storage/Logic
    /// -----------------------------------------------------------------------

    /// @dev Renderer for metadata (set in master contract)
    KaliClubSig private immutable renderer;
    /// @dev Metadata emblem for club
    string private baseURI;
    /// @dev Tx counter - initialized at `1` for cheaper first tx
    uint64 public nonce;
    /// @dev Signature (NFT) threshold to execute tx
    uint64 public quorum;
    /// @dev Total signer units minted
    uint64 public totalSupply;

    /// @dev Administrative account tracking
    mapping(address => bool) public governor;

    /// @dev Access control for this contract and governors
    modifier onlyClubOrGov() {
        if (msg.sender != address(this) && !governor[msg.sender])
            revert Forbidden();
        _;
    }
    
    /// @dev Metadata logic that returns external reference if no local
    function tokenURI(uint256 id) external view returns (string memory) {
        if (bytes(baseURI).length == 0) {
            return renderer.tokenURI(id);
        } else {
            return baseURI;
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
    
    constructor(KaliClubSig _renderer) payable {
        renderer = _renderer;
    }

    function init(
        Call[] calldata calls,
        Member[] calldata members,
        uint256 threshold,
        bool paused,
        string calldata uri
    ) external payable {
        if (nonce != 0) revert AlreadyInit();

        assembly {
            if iszero(threshold) {
                revert(0, 0)
            }
        }

        if (threshold > members.length) revert QuorumOverSigs();

        if (calls.length != 0) {
            for (uint256 i; i < calls.length; ) {
                _execute(
                    calls[i].op, 
                    calls[i].to, 
                    calls[i].value, 
                    calls[i].data
                );

                // cannot realistically overflow
                unchecked {
                    ++i;
                }
            }
        }

        address prevAddr;
        uint256 supply;
        nonce = 1;

        for (uint256 i; i < members.length; ) {
            // prevent null and duplicate signers
            if (prevAddr >= members[i].signer) revert InvalidSig();

            prevAddr = members[i].signer;

            _safeMint(members[i].signer, members[i].id);

            // cannot realistically overflow
            unchecked {
                ++supply;
                ++i;
            }
        }

        quorum = uint64(threshold);
        totalSupply = uint64(supply);
        baseURI = uri;
        ClubNFT._setPause(paused);
        INITIAL_DOMAIN_SEPARATOR = _computeDomainSeparator();
    }

    /// -----------------------------------------------------------------------
    /// Operations
    /// -----------------------------------------------------------------------

    function getDigest(
        Operation op,
        address to,
        uint256 value,
        bytes calldata data,
        uint256 txNonce
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
                                'Exec(Operation op,address to,uint256 value,bytes data,uint256 txNonce)'
                            ),
                            op,
                            to,
                            value,
                            data,
                            txNonce
                        )
                    )
                )
            );
    }
    
    /// @notice Execute operation from club with signatures
    /// @param op The enum operation to execute
    /// @param to Address to send operation to
    /// @param value Amount of ETH to send in operation
    /// @param data Payload to send in operation
    /// @param sigs Array of signatures from NFT sorted in ascending order by addresses
    /// @dev Make sure signatures are sorted in ascending order - otherwise verification will fail
    /// @return success Fetches whether operation succeeded
    function execute(
        Operation op,
        address to,
        uint256 value,
        bytes calldata data,
        Signature[] calldata sigs
    ) external payable returns (bool success) {
        // begin signature validation with payload hash
        bytes32 digest = getDigest(op, to, value, data, nonce);
        // starting from zero address in loop to ensure addresses are ascending
        address prevAddr;
        // validation is length of quorum threshold 
        uint256 threshold = quorum;

        for (uint256 i; i < threshold; ) {
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
                ) revert InvalidSig();
            }

            // check for NFT balance and duplicates
            if (balanceOf[signer] == 0 || prevAddr >= signer)
                revert InvalidSig();

            // set prevAddr to signer for next iteration until quorum
            prevAddr = signer;

            // cannot realistically overflow
            unchecked {
                ++i;
            }
        }
        
        success = _execute(
            op,
            to, 
            value, 
            data
        );
    }
    
    /// @notice Execute operations from club with signed execute() or as governor
    /// @param calls Arrays of `op, to, value, data`
    /// @return successes Fetches whether operations succeeded
    function batchExecute(Call[] calldata calls) external payable onlyClubOrGov returns (bool[] memory successes) {
        successes = new bool[](calls.length);

        for (uint256 i; i < calls.length; ) {
            successes[i] = _execute(
                calls[i].op,
                calls[i].to, 
                calls[i].value, 
                calls[i].data
            );

            // cannot realistically overflow
            unchecked {
                ++i;
            }
        }
    }

    function _execute(
        Operation op,
        address to, 
        uint256 value, 
        bytes memory data
    ) private returns (bool success) {
        // cannot realistically overflow
        unchecked {
            ++nonce;
        }

        if (op == Operation.call) {
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
        } else if (op == Operation.delegateCall) {
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
        } else {
            assembly {
                success := create(value, add(data, 0x20), mload(data))
            }
        }

        if (!success) revert ExecuteFailed();

        emit Execute(to, value, data);
    }
    
    /// @notice Update club configurations for membership and quorum
    /// @param members Arrays of `mint, signer, id` for membership
    /// @param threshold Signature threshold to execute() operations
    function govern(Member[] calldata members, uint256 threshold) external payable onlyClubOrGov {
        assembly {
            if iszero(threshold) {
                revert(0, 0)
            }
        }

        uint256 supply = totalSupply;

        // cannot realistically overflow, and
        // cannot underflow because ownership is checked in burn()
        unchecked {
            for (uint256 i; i < members.length; ++i) {
                if (members[i].mint) {
                    // mint NFT, update supply
                    _safeMint(members[i].signer, members[i].id);
                    ++supply;
                } else {
                    // burn NFT, update supply
                    _burn(members[i].id);
                    --supply;
                }
            }
        }

        // note: also make sure that signers don't concentrate NFTs,
        // since this could cause issues in reaching quorum
        if (threshold > supply) revert QuorumOverSigs();

        quorum = uint64(threshold);
        totalSupply = uint64(supply);

        emit Govern(members, threshold);
    }

    function setGovernor(address account, bool approved)
        external
        payable
        onlyClubOrGov
    {
        governor[account] = approved;
        emit GovernorSet(account, approved);
    }

    function setSignerPause(bool paused_) external payable onlyClubOrGov {
        ClubNFT._setPause(paused_);
    }

    function setURI(string calldata baseURI_) external payable onlyClubOrGov {
        baseURI = baseURI_;
        emit URIset(baseURI_);
    }
}
