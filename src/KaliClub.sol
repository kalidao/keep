// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

/// @dev Interfaces
import {IMember} from './interfaces/IMember.sol';
import {IERC1271} from './interfaces/IERC1271.sol';

/// @dev Contracts
import {ClubNFT} from './ClubNFT.sol';
import {Multicall} from './utils/Multicall.sol';
import {NFTreceiver} from './utils/NFTreceiver.sol';

/// @title Kali Club
/// @notice EIP-712-signed multi-sig with ERC-1155 NFT ids for signers
/// @author Modified from MultiSignatureWallet (https://github.com/SilentCicero/MultiSignatureWallet)
/// License-Identifier: MIT
/// and LilGnosis (https://github.com/m1guelpf/lil-web3/blob/main/src/LilGnosis.sol)
/// License-Identifier: AGPL-3.0-only
/// @dev Lightweight implementation of Moloch v3 
/// (https://github.com/Moloch-Mystics/Baal/blob/main/contracts/Baal.sol)
/// License-Identifier: UNLICENSED

enum Operation {
    call,
    delegatecall,
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

contract KaliClub is IMember, ClubNFT, Multicall, NFTreceiver {
    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    /// @notice Emitted when multi-sig executes operation
    event Execute(
        Operation op,
        address indexed to, 
        uint256 value, 
        bytes data
    );

    /// @notice Emitted when members and quorum threshold are updated
    event Govern(Member[] members, uint256 threshold);

    /// @notice Emitted when governance access is updated
    event GovernanceSet(address indexed account, bool approve);

    /// @notice Emitted when metadata base for club is updated
    event URIset(string baseURI);

    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    /// @notice Throws if init() is called more than once
    error AlreadyInit();

    /// @notice Throws if quorum threshold exceeds signer supply
    error QuorumOverSigs();

    /// @notice Throws if signature doesn't verify execute()
    error InvalidSig();

    /// @notice Throws if execute() doesn't complete operation
    error ExecuteFailed();

    /// -----------------------------------------------------------------------
    /// Club Storage/Logic
    /// -----------------------------------------------------------------------

    /// @notice Renderer for metadata (set in master contract)
    KaliClub internal immutable uriFetcher;

    /// @notice Metadata base for club
    string internal baseURI;

    /// @notice Club tx counter
    uint64 public nonce;

    /// @notice Signature (NFT) threshold to execute tx
    uint64 public quorum;

    /// @notice Total key signers minted
    uint64 public totalSupply;

    /// @notice Governance access tracking
    mapping(address => bool) public governance;

    /// @notice Access control for club and governance
    modifier onlyClubOrGovernance() {
        if (msg.sender != address(this) && !governance[msg.sender])
            revert Forbidden();

        _;
    }
    
    /// @notice Metadata logic that returns external reference if no local
    function tokenURI(uint256 id) external view returns (string memory) {
        if (bytes(baseURI).length == 0) {
            return uriFetcher.tokenURI(id);
        } else {
            return baseURI;
        }
    }

    /// -----------------------------------------------------------------------
    /// EIP-712 Storage/Logic
    /// -----------------------------------------------------------------------

    bytes32 internal INITIAL_DOMAIN_SEPARATOR;

    function INITIAL_CHAIN_ID() internal pure returns (uint256 chainId) {
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

    function _computeDomainSeparator() internal view returns (bytes32) {
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
    
    constructor(KaliClub _uriFetcher) payable {
        uriFetcher = _uriFetcher;
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

                // won't realistically overflow
                unchecked {
                    ++i;
                }
            }
        }

        address prevAddr;
        uint256 supply;

        for (uint256 i; i < members.length; ) {
            // prevent null and duplicate signers
            if (prevAddr >= members[i].signer) revert InvalidSig();

            prevAddr = members[i].signer;

            _safeMint(members[i].signer, members[i].id);

            // won't realistically overflow
            unchecked {
                ++supply;
                ++i;
            }
        }
     
        nonce = 1;
        quorum = uint64(threshold);
        totalSupply = uint64(supply);
        if (bytes(uri).length != 0) baseURI = uri;
        // if (nontransferable) ClubNFT._setPause(true);
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
        // begin signature validation with call data
        bytes32 digest = getDigest(op, to, value, data, nonce);
        // start from null in loop to ensure ascending addresses
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

            // check contract signature using EIP-1271
            if (signer.code.length != 0) {
                if (
                    IERC1271(signer).isValidSignature(
                        digest,
                        abi.encodePacked(sigs[i].r, sigs[i].s, sigs[i].v)
                    ) != IERC1271.isValidSignature.selector
                ) revert InvalidSig();
            }

            // check NFT balance and duplicates
            if (balanceOf[signer] == 0 || prevAddr >= signer)
                revert InvalidSig();

            // set prevAddr to signer for next iteration until quorum
            prevAddr = signer;

            // won't realistically overflow
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
    function batchExecute(Call[] calldata calls) external payable onlyClubOrGovernance returns (bool[] memory successes) {
        successes = new bool[](calls.length);

        for (uint256 i; i < calls.length; ) {
            successes[i] = _execute(
                calls[i].op,
                calls[i].to, 
                calls[i].value, 
                calls[i].data
            );

            // won't realistically overflow
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
    ) internal returns (bool success) {
        // won't realistically overflow
        unchecked {
            ++nonce;
        }

        if (op == Operation.call) {
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

            emit Execute(op, to, value, data);
        } else if (op == Operation.delegatecall) {
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

            emit Execute(op, to, value, data);
        } else if (op == Operation.create) {
            assembly {
                success := create(value, add(data, 0x20), mload(data))
            }
        } else {
            bytes32 salt = bytes32(bytes20(to));

            assembly {
                success := create2(value, add(0x20, data), mload(data), salt)
            }
        }

        if (!success) revert ExecuteFailed();
    }
    
    /// @notice Update club configurations for membership and quorum
    /// @param members Arrays of `mint, signer, id` for membership
    /// @param threshold Signature threshold to execute() operations
    function govern(Member[] calldata members, uint256 threshold) external payable onlyClubOrGovernance {
        assembly {
            if iszero(threshold) {
                revert(0, 0)
            }
        }

        uint256 supply = totalSupply;

        // won't realistically overflow, and
        // won't underflow because checked in burn()
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

        // note: also make sure signers don't concentrate NFTs,
        // as this could cause issues in reaching quorum
        if (threshold > supply) revert QuorumOverSigs();

        quorum = uint64(threshold);
        totalSupply = uint64(supply);

        emit Govern(members, threshold);
    }

    function setGovernance(address account, bool approve)
        external
        payable
        onlyClubOrGovernance
    {
        governance[account] = approve;

        emit GovernanceSet(account, approve);
    }

    function setPause(bool pause) external payable onlyClubOrGovernance {
        ClubNFT._setPause(pause);
    }

    function setBaseURI(string calldata uri) external payable onlyClubOrGovernance {
        baseURI = uri;

        emit URIset(uri);
    }
}
