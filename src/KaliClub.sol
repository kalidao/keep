// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

/// @dev Interfaces
import {IERC1271} from "./interfaces/IERC1271.sol";

/// @dev Contracts
import {ERC1155votes} from "./ERC1155votes.sol";
import {Multicall} from "./utils/Multicall.sol";
import {NFTreceiver} from "./utils/NFTreceiver.sol";

/// @title Kali Club
/// @notice EIP-712-signed multi-sig with ERC-1155 NFT for signers
/// @author Modified from MultiSignatureWallet (https://github.com/SilentCicero/MultiSignatureWallet)
/// and LilGnosis (https://github.com/m1guelpf/lil-web3/blob/main/src/LilGnosis.sol)
/// @dev Lightweight implementation of Moloch v3 
/// (https://github.com/Moloch-Mystics/Baal/blob/main/contracts/Baal.sol)

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

struct Signer {
    bool mint;
    address signer;
}

contract KaliClub is ERC1155votes, Multicall, NFTreceiver {
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

    /// @notice Emitted when signers and quorum threshold are updated
    event Govern(Signer[] signers, uint256 threshold);

    /// @notice Emitted when governance access is updated
    event GovernanceSet(address indexed account, bool approve);

    /// @notice Emitted when admin access is set
    event AdminSet(address indexed caller, address indexed to);

    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    /// @notice Throws if init() is called more than once
    error ALREADY_INIT();

    /// @notice Throws if quorum threshold exceeds signer supply
    error QUORUM_OVER_SIGS();

    /// @notice Throws if signature doesn't verify execute()
    error INVALID_SIG();

    /// @notice Throws if execute() doesn't complete operation
    error EXECUTE_FAILED();

    /// -----------------------------------------------------------------------
    /// Club Storage/Logic
    /// -----------------------------------------------------------------------
    
    address public admin;
    
    /// @notice Renderer for metadata (set in master contract)
    KaliClub internal immutable uriFetcher;

    /// @notice Club tx counter
    uint64 public nonce;

    /// @notice Signature (NFT) threshold to execute tx
    uint64 public quorum;

    /// @notice Total key signers minted (ID 0)
    uint64 public totalSupply;

    /// @notice Governance access tracking
    mapping(address => bool) public governance;

    /// @notice Token URI metadata tracking
    mapping(uint256 => string) internal tokenURIs;

    /// @notice Access control for club
    modifier onlyClub() {
        if (msg.sender != address(this)) revert NOT_AUTHORIZED();

        _;
    }

    /// @notice Access control for club and governance
    modifier onlyClubGovernance() {
        if (
            msg.sender != address(this) 
            && !governance[msg.sender]
            && !admin[msg.sender]
        )
            revert NOT_AUTHORIZED();

        _;
    }
    
    /// @notice Metadata logic that returns external reference if no local
    function uri(uint256 id) external view returns (string memory) {
        if (bytes(tokenURIs[id]).length == 0) return uriFetcher.uri(id);
        else return tokenURIs[id];
    }

    /// -----------------------------------------------------------------------
    /// EIP-712 Storage/Logic
    /// -----------------------------------------------------------------------

    bytes32 internal _INITIAL_DOMAIN_SEPARATOR;

    function _INITIAL_CHAIN_ID() internal pure returns (uint256 chainId) {
        uint256 offset;

        assembly {
            offset := sub(
                calldatasize(),
                add(shr(240, calldataload(sub(calldatasize(), 2))), 2)
            )
        }
        
        assembly {
            chainId := calldataload(add(offset, argOffset))
        }
    }

    function DOMAIN_SEPARATOR() public view returns (bytes32) {
        return
            block.chainid == _INITIAL_CHAIN_ID()
                ? _INITIAL_DOMAIN_SEPARATOR
                : _computeDomainSeparator();
    }

    function _computeDomainSeparator() internal view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    keccak256(
                        'EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'
                    ),
                    keccak256(bytes('KaliClub')),
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
        address[] calldata signers,
        uint256 threshold
    ) external payable {
        if (nonce != 0) revert ALREADY_INIT();

        assembly {
            if iszero(threshold) {
                revert(0, 0)
            }
        }

        if (threshold > signers.length) revert QUORUM_OVER_SIGS();

        if (calls.length != 0) {
            for (uint256 i; i < calls.length; ) {
                _execute(
                    calls[i].op, 
                    calls[i].to, 
                    calls[i].value, 
                    calls[i].data
                );

                // an array can't have a total length
                // larger than the max uint256 value
                unchecked {
                    ++i;
                }
            }
        }

        address prevAddr;
        uint256 supply;

        for (uint256 i; i < signers.length; ) {
            // prevent null and duplicate signers
            if (prevAddr >= signers[i]) revert INVALID_SIG();

            prevAddr = signers[i];

            _mintSigner(signers[i]);

            // won't realistically overflow
            unchecked {
                ++supply;
                ++i;
            }
        }
     
        nonce = 1;
        quorum = uint64(threshold);
        totalSupply = uint64(supply);
        _INITIAL_DOMAIN_SEPARATOR = _computeDomainSeparator();
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
                ) revert INVALID_SIG();
            }

            // check NFT balance and duplicates
            if (balanceOf[signer][0] == 0 || prevAddr >= signer)
                revert INVALID_SIG();

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
    function batchExecute(Call[] calldata calls) external payable onlyClubGovernance returns (bool[] memory successes) {
        successes = new bool[](calls.length);

        for (uint256 i; i < calls.length; ) {
            successes[i] = _execute(
                calls[i].op,
                calls[i].to, 
                calls[i].value, 
                calls[i].data
            );

            // an array can't have a total length
            // larger than the max uint256 value
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

        if (!success) revert EXECUTE_FAILED();
    }
    
    /// @notice Update club configurations for signers and quorum
    /// @param signers Arrays of `mint, signer` for signers
    /// @param threshold Signature threshold to execute() operations
    function govern(Signer[] calldata signers, uint256 threshold) external payable onlyClubGovernance {
        assembly {
            if iszero(threshold) {
                revert(0, 0)
            }
        }

        uint256 supply = totalSupply;

        // won't realistically overflow, and
        // won't underflow because checked in burn()
        unchecked {
            for (uint256 i; i < signers.length; ++i) {
                if (signers[i].mint) {
                    // mint signer NFT (ID 0), update supply
                    _mintSigner(signers[i].signer);

                    ++supply;
                } else {
                    // burn signer NFT (ID 0), update supply
                    _burnSigner(signers[i].signer);
                    
                    --supply;
                }
            }
        }

        // note: also make sure signers don't concentrate NFTs,
        // as this could cause issues in reaching quorum
        if (threshold > supply) revert QUORUM_OVER_SIGS();

        quorum = uint64(threshold);
        totalSupply = uint64(supply);

        emit Govern(signers, threshold);
    }

    function mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) external payable onlyClubGovernance {
        if (id == 0) revert SIGNER_ID();

        _mint(to, id, amount, data);
    }

    function _mintSigner(address to) internal {
        // won't realistically overflow
        unchecked {
            ++balanceOf[to][0];
        }

        emit TransferSingle(msg.sender, address(0), to, 0, 1);
    }

    function burn(
        address from, 
        uint256 id, 
        uint256 amount
    ) external payable {
        if (id == 0) revert SIGNER_ID();

        if (msg.sender != from && !isApprovedForAll[from][msg.sender]) revert NOT_AUTHORIZED();

        _burn(from, id, amount);
    }

    function _burnSigner(address from) internal {
        --balanceOf[from][0];

        emit TransferSingle(msg.sender, from, address(0), 0, 1);
    } 

    function setAdmin(address to) external payable onlyClub {
        admin = to;

        emit AdminSet(msg.sender, to);
    }

    function setGovernance(address account, bool approve)
        external
        payable
        onlyClubGovernance
    {
        governance[account] = approve;

        emit GovernanceSet(account, approve);
    }

    function setTokenPause(uint256 id, bool transferability) external payable onlyClubGovernance {
        transferable[id] = transferability;

        emit TokenTransferabilitySet(msg.sender, id, transferability);
    }

    function setTokenURI(uint256 id, string calldata tokenURI) external payable onlyClubGovernance {
        tokenURIs[id] = tokenURI;

        emit URI(tokenURI, id);
    }
}
