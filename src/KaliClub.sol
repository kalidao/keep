// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

/// @dev Interfaces
import {IERC1271} from "./interfaces/IERC1271.sol";

/// @dev Contracts
import {ERC1155votes} from "./ERC1155votes.sol";
import {Multicall} from "./utils/Multicall.sol";
import {NFTreceiver} from "./utils/NFTreceiver.sol";

/// @title Kali Club
/// @notice EIP-712 multi-sig with ERC-1155 for signers
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

contract KaliClub is ERC1155votes, Multicall, NFTreceiver {
    /// -----------------------------------------------------------------------
    /// EVENTS
    /// -----------------------------------------------------------------------

    /// @notice Emitted when club executes call
    event Executed(
        Operation op,
        address indexed to, 
        uint256 value, 
        bytes data
    );

    /// @notice Emitted when club executes contract creation
    event ContractCreated(
        Operation op,
        address deployment,
        uint256 value
    );

    /// @notice Emitted when quorum threshold is updated
    event QuorumSet(address indexed caller, uint256 threshold);

    /// @notice Emitted when admin access is set
    event AdminSet(address indexed to);

    /// @notice Emitted when governance access is updated
    event GovernanceSet(
        address indexed caller, 
        address indexed to, 
        bool approve
    );

    /// -----------------------------------------------------------------------
    /// ERRORS
    /// -----------------------------------------------------------------------

    /// @notice Throws if init() is called more than once
    error ALREADY_INIT();

    /// @notice Throws if quorum threshold exceeds totalSupply()
    error QUORUM_OVER_SUPPLY();

    /// @notice Throws if signature doesn't verify execute()
    error INVALID_SIG();

    /// @notice Throws if execute() doesn't complete operation
    error EXECUTE_FAILED();

    /// -----------------------------------------------------------------------
    /// CLUB STORAGE/LOGIC
    /// -----------------------------------------------------------------------
    
    /// @notice Renderer for metadata set in master contract
    KaliClub internal immutable uriFetcher;

    /// @notice Club tx counter
    uint64 public nonce;

    /// @notice Signature NFT threshold to execute tx
    uint64 public quorum;

    /// @notice Total signers minted 
    uint128 public totalSupply;

    /// @notice Initial club domain value 
    bytes32 internal _INITIAL_DOMAIN_SEPARATOR;

    /// @notice Admin access tracking
    mapping(address => bool) public admin;

    /// @notice Governance access tracking
    mapping(address => bool) public governance;

    /// @notice Token URI metadata tracking
    mapping(uint256 => string) internal _tokenURIs;

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
    
    /// @notice Token URI metadata fetcher
    /// @dev Fetches external reference if no local
    function uri(uint256 id) external view returns (string memory) {
        if (bytes(_tokenURIs[id]).length == 0) return uriFetcher.uri(id);
        else return _tokenURIs[id];
    }

    /// -----------------------------------------------------------------------
    /// EIP-712 LOGIC
    /// -----------------------------------------------------------------------

    /// @notice Fetches unique club domain for signatures
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

    function _INITIAL_CHAIN_ID() internal pure returns (uint256 chainId) {
        uint256 offset;

        assembly {
            offset := sub(
                calldatasize(),
                add(shr(240, calldataload(sub(calldatasize(), 2))), 2)
            )
        }
        
        assembly {
            chainId := calldataload(add(offset, 5))
        }
    }

    /// -----------------------------------------------------------------------
    /// INITIALIZER LOGIC
    /// -----------------------------------------------------------------------
    
    /// @notice Deploys master contract template
    /// @param _uriFetcher ID metadata manager
    constructor(KaliClub _uriFetcher) payable {
        uriFetcher = _uriFetcher;
    }

    /// @notice Initializes club configuration
    /// @param calls Initial club operations
    /// @param signers Initial signer set
    /// @param threshold Initial quorum
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

        if (threshold > signers.length) revert QUORUM_OVER_SUPPLY();

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
        
        address signer;
        address prevAddr;
        uint128 supply;

        for (uint256 i; i < signers.length; ) {
            signer = signers[i];

            // prevent null and duplicate signers
            if (prevAddr >= signer) revert INVALID_SIG();

            prevAddr = signer;

            // won't realistically overflow
            unchecked {
                ++balanceOf[signer][0];

                ++supply;

                ++i;
            }

            emit TransferSingle(msg.sender, address(0), signer, 0, 1);
        }

        nonce = 1;
        quorum = uint64(threshold);
        totalSupply = supply;
        _INITIAL_DOMAIN_SEPARATOR = _computeDomainSeparator();
    }

    /// -----------------------------------------------------------------------
    /// OPERATIONAL LOGIC
    /// -----------------------------------------------------------------------

    /// @notice Fetches digest from club operation
    /// @param op The enum operation to execute
    /// @param to Address to send operation to
    /// @param value Amount of ETH to send in operation
    /// @param data Payload to send in operation
    /// @param txNonce Club tx index
    /// @return Digest for operation
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
    /// @return success Whether operation succeeded
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
    
    /// @notice Execute operations from club with signed execute() or as governance
    /// @param calls Club operations as arrays of `op, to, value, data`
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

            emit Executed(op, to, value, data);
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

            emit Executed(op, to, value, data);
        } else if (op == Operation.create) {
            address deployment;

            assembly {
                deployment := create(value, add(data, 0x20), mload(data))

                if iszero(deployment) {
                    revert(0, 0)
                }
            }

            emit ContractCreated(op, deployment, value);
        } else {
            address deployment;

            bytes32 salt = bytes32(bytes20(to));

            assembly {
                deployment := create2(value, add(0x20, data), mload(data), salt)

                if iszero(deployment) {
                    revert(0, 0)
                }
            }

            emit ContractCreated(op, deployment, value);
        }

        if (!success) revert EXECUTE_FAILED();
    }
    
    /// @notice Update club quorum
    /// @param threshold Signature threshold to execute() operations
    function setQuorum(uint256 threshold) external payable onlyClubGovernance {
        // note: also make sure signers don't concentrate NFTs,
        // as this could cause issues in reaching quorum
        if (threshold > totalSupply) revert QUORUM_OVER_SUPPLY();

        quorum = _safeCastTo64(threshold);

        emit QuorumSet(msg.sender, threshold);
    }

    /// @notice Club token ID minter
    /// @param to The recipient of mint
    /// @param id The token ID to mint
    /// @param amount The amount to mint
    /// @param data Optional data payload
    /// @dev Token ID cannot be null
    function mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) external payable onlyClubGovernance {
        assembly {
            if iszero(id) {
                revert(0, 0)
            }
        }

        _mint(to, id, amount, data);
    }

    /// @notice Club signer minter
    /// @param to The recipient of signer mint
    function mintSigner(address to) public payable onlyClubGovernance {
        // won't realistically overflow
        unchecked {
            ++balanceOf[to][0];

            ++totalSupply;
        }

        emit TransferSingle(msg.sender, address(0), to, 0, 1);
    }

    /// @notice Club token ID burner
    /// @param from The account to burn from
    /// @param id The token ID to burn
    /// @param amount The amount to burn
    /// @dev Token ID cannot be null
    function burn(
        address from, 
        uint256 id, 
        uint256 amount
    ) external payable {
        assembly {
            if iszero(id) {
                revert(0, 0)
            }
        }

        if (
            msg.sender != from
            && !isApprovedForAll[from][msg.sender] 
            && msg.sender != address(this)
            && !governance[msg.sender]
            && !admin[msg.sender]
        )
            revert NOT_AUTHORIZED();

        _burn(from, id, amount);
    }

    /// @notice Club signer burner
    /// @param from The account to burn signer from
    function burnSigner(address from) external payable onlyClubGovernance {
        --balanceOf[from][0];

        // won't underflow as supply is checked above
        unchecked {
            --totalSupply;
        }

        if (quorum > totalSupply) revert QUORUM_OVER_SUPPLY();

        emit TransferSingle(msg.sender, from, address(0), 0, 1);
    } 

    /// @notice Club admin setter
    /// @param to The account to set admin to
    function setAdmin(address to) external payable {
        if (msg.sender != address(this)) revert NOT_AUTHORIZED();

        admin[to] = true;

        emit AdminSet(to);
    }

    /// @notice Club governance setter
    /// @param to The account to set governance to
    /// @param approve The approval setting
    function setGovernance(address to, bool approve)
        external
        payable
        onlyClubGovernance
    {
        governance[to] = approve;

        emit GovernanceSet(msg.sender, to, approve);
    }

    /// @notice Club token ID transferability setter
    /// @param id The token ID to set transferability for
    /// @param transferability The transferability setting
    function setTokenTransferability(uint256 id, bool transferability) external payable onlyClubGovernance {
        transferable[id] = transferability;

        emit TokenTransferabilitySet(msg.sender, id, transferability);
    }

    /// @notice Club token ID metadata setter
    /// @param id The token ID to set metadata for
    /// @param tokenURI The metadata setting
    function setTokenURI(uint256 id, string calldata tokenURI) external payable onlyClubGovernance {
        _tokenURIs[id] = tokenURI;

        emit URI(tokenURI, id);
    }
}
