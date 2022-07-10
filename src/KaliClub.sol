// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

/// @dev Interfaces
import {IERC1271} from "./interfaces/IERC1271.sol";

/// @dev Contracts
import {ERC721TokenReceiver} from "./utils/ERC721TokenReceiver.sol";
import {ERC1155TokenReceiver, ERC1155Votes} from "./ERC1155Votes.sol";
import {Multicall} from "./utils/Multicall.sol";

/// @title Kali Club
/// @notice EIP-712 multi-sig with ERC-1155 interface
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

contract KaliClub is 
    ERC721TokenReceiver, 
    ERC1155TokenReceiver, 
    ERC1155Votes, 
    Multicall 
{
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

    /// @notice Emitted when club creates contract
    event ContractCreated(
        Operation op,
        address indexed creation,
        uint256 value
    );

    /// @notice Emitted when quorum threshold is updated
    event QuorumSet(address indexed caller, uint32 threshold);

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
    /// CLUB CONSTANTS
    /// -----------------------------------------------------------------------

    uint32 internal constant EXECUTE_ID = uint32(uint256(bytes32(this.execute.selector)));
    uint32 internal constant BATCH_EXECUTE_ID =  uint32(uint256(bytes32(this.batchExecute.selector)));
    uint32 internal constant MINT_ID = uint32(uint256(bytes32(this.mint.selector)));
    uint32 internal constant BURN_ID = uint32(uint256(bytes32(this.burn.selector)));
    uint32 internal constant SET_QUORUM_ID = uint32(uint256(bytes32(this.setQuorum.selector)));
    uint32 internal constant SET_TRANSFERABILITY_ID = uint32(uint256(bytes32(this.setTransferability.selector)));
    uint32 internal constant SET_URI_ID = uint32(uint256(bytes32(this.setURI.selector)));

    bytes32 internal constant DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );
    bytes32 internal constant EXECUTE_TYPEHASH = keccak256(
        "Execute(Operation op,address to,uint256 value,bytes data,uint256 nonce)"
    );

    /// -----------------------------------------------------------------------
    /// CLUB STORAGE/LOGIC
    /// -----------------------------------------------------------------------
    
    /// @notice Club tx counter
    uint64 public nonce;

    /// @notice Signature NFT threshold to execute()
    uint32 public quorum;

    /// @notice Initial club domain value 
    bytes32 public _INITIAL_DOMAIN_SEPARATOR;

    /// @notice URI metadata tracking
    mapping(uint256 => string) internal _uris;
    
    /// @notice Token URI metadata fetcher
    /// @param id The token ID to fetch from
    /// @return Token URI metadata reference
    function uri(uint256 id) public view override virtual returns (string memory) {
        return _uris[id];
    }

    /// @notice Access control for club and authorized ID holders
    function _authorized(uint256 id) internal view returns (bool) {
        if (msg.sender == address(this) || balanceOf[msg.sender][id] != 0
        ) return true; else revert NOT_AUTHORIZED();
    }

    /// -----------------------------------------------------------------------
    /// ERC-165 LOGIC
    /// -----------------------------------------------------------------------

    /// @notice ERC-165 interface detection
    /// @param interfaceId The interface ID to check
    /// @return Interface detection success
    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return
            interfaceId == this.onERC721Received.selector || // ERC-165 Interface ID for ERC721TokenReceiver 
            interfaceId == 0x4e2312e0 || // ERC-165 Interface ID for ERC1155TokenReceiver
            super.supportsInterface(interfaceId); // ERC-165 Interface IDs for ERC-1155
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

    function _computeDomainSeparator() internal view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    DOMAIN_TYPEHASH,
                    keccak256(bytes('KaliClub')),
                    keccak256('1'),
                    block.chainid,
                    address(this)
                )
            );
    }

    /// -----------------------------------------------------------------------
    /// INITIALIZATION LOGIC
    /// -----------------------------------------------------------------------

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
                ++balanceOf[signer][EXECUTE_ID];

                ++supply;

                ++i;
            }

            emit TransferSingle(msg.sender, address(0), signer, EXECUTE_ID, 1);
        }

        nonce = 1;
        quorum = uint32(threshold);
        totalSupply[EXECUTE_ID] = supply;
        _INITIAL_DOMAIN_SEPARATOR = _computeDomainSeparator();
    }

    /// -----------------------------------------------------------------------
    /// EXECUTION LOGIC
    /// -----------------------------------------------------------------------

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
        bytes32 digest = 
            keccak256(
                abi.encodePacked(
                    '\x19\x01',
                    DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            EXECUTE_TYPEHASH,
                            op,
                            to,
                            value,
                            data,
                            nonce
                        )
                    )
                )
            );
        
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

            // check NFT balance
            if (balanceOf[signer][EXECUTE_ID] == 0) revert INVALID_SIG();
            // check duplicates
            if (prevAddr >= signer) revert INVALID_SIG();

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
    function batchExecute(Call[] calldata calls) external payable returns (bool[] memory successes) {
        _authorized(BATCH_EXECUTE_ID);

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

            if (!success) revert EXECUTE_FAILED();

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

            if (!success) revert EXECUTE_FAILED();

            emit Executed(op, to, value, data);
        } else if (op == Operation.create) {
            address creation;

            assembly {
                creation := create(value, add(data, 0x20), mload(data))
            }

            if (creation == address(0)) revert EXECUTE_FAILED();

            emit ContractCreated(op, creation, value);
        } else {
            address creation;
            bytes32 salt = bytes32(bytes20(to));

            assembly {
                creation := create2(value, add(0x20, data), mload(data), salt)
            }

            if (creation == address(0)) revert EXECUTE_FAILED();

            emit ContractCreated(op, creation, value);
        }
    }
    
    /// -----------------------------------------------------------------------
    /// MINT/BURN LOGIC
    /// -----------------------------------------------------------------------

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
    ) external payable {
        _authorized(MINT_ID);

        _mint(to, id, amount, data);
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
        if (
            msg.sender != from 
            && !isApprovedForAll[from][msg.sender] 
            && !_authorized(BURN_ID)
        ) revert NOT_AUTHORIZED();

        _burn(from, id, amount);

        if (id == EXECUTE_ID)
            if (quorum > totalSupply[EXECUTE_ID]) 
                revert QUORUM_OVER_SUPPLY();
    }

    /// -----------------------------------------------------------------------
    /// THRESHOLD SETTING LOGIC
    /// -----------------------------------------------------------------------
    
    /// @notice Update club quorum
    /// @param threshold Signature threshold to execute() operations
    function setQuorum(uint32 threshold) external payable {
        _authorized(SET_QUORUM_ID);

        assembly {
            if iszero(threshold) {
                revert(0, 0)
            }
        }
        
        // note: also make sure signers don't concentrate NFTs,
        // as this could cause issues in reaching quorum
        if (threshold > totalSupply[EXECUTE_ID]) revert QUORUM_OVER_SUPPLY();

        quorum = threshold;

        emit QuorumSet(msg.sender, threshold);
    }
    
    /// -----------------------------------------------------------------------
    /// ID SETTING LOGIC
    /// -----------------------------------------------------------------------

    /// @notice Club token ID transferability setter
    /// @param id The token ID to set transferability for
    /// @param transferability The transferability setting
    function setTransferability(uint256 id, bool transferability) external payable {
        _authorized(SET_TRANSFERABILITY_ID);

        _setTransferability(id, transferability);
    }

    /// @notice Club token ID metadata setter
    /// @param id The token ID to set metadata for
    /// @param tokenURI The metadata setting
    function setURI(uint256 id, string calldata tokenURI) external payable {
        _authorized(SET_URI_ID);

        _uris[id] = tokenURI;

        emit URI(tokenURI, id);
    }
}
