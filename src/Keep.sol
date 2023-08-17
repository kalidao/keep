// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {ERC1155TokenReceiver, KeepToken} from "./KeepToken.sol";
import {Multicallable} from "./utils/Multicallable.sol";

/// @title Keep
/// @notice Tokenized multisig wallet.
/// @author z0r0z.eth
/// @custom:coauthor @ControlCplusControlV
/// @custom:coauthor boredretard.eth
/// @custom:coauthor vectorized.eth
/// @custom:coauthor horsefacts.eth
/// @custom:coauthor shivanshi.eth
/// @custom:coauthor @0xAlcibiades
/// @custom:coauthor LeXpunK Army
/// @custom:coauthor @0xmichalis
/// @custom:coauthor @iFrostizz
/// @custom:coauthor @m1guelpf
/// @custom:coauthor @asnared
/// @custom:coauthor @0xPhaze
/// @custom:coauthor out.eth

enum Operation {
    call,
    delegatecall,
    create
}

struct Call {
    Operation op;
    address to;
    uint256 value;
    bytes data;
}

struct Signature {
    address user;
    uint8 v;
    bytes32 r;
    bytes32 s;
}

struct UserOperation {
    address sender;
    uint256 nonce;
    bytes initCode;
    bytes callData;
    uint256 callGasLimit;
    uint256 verificationGasLimit;
    uint256 preVerificationGas;
    uint256 maxFeePerGas;
    uint256 maxPriorityFeePerGas;
    bytes paymasterAndData;
    bytes signature;
}

contract Keep is ERC1155TokenReceiver, KeepToken, Multicallable {
    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    /// @dev Emitted when Keep executes call.
    event Executed(
        uint256 indexed nonce,
        Operation op,
        address to,
        uint256 value,
        bytes data
    );

    /// @dev Emitted when Keep relays call.
    event Relayed(Call call);

    /// @dev Emitted when Keep relays calls.
    event Multirelayed(Call[] calls);

    /// @dev Emitted when quorum threshold is updated.
    event QuorumSet(uint256 threshold);

    /// -----------------------------------------------------------------------
    /// Custom Errors
    /// -----------------------------------------------------------------------

    /// @dev Throws if `initialize()` is called more than once.
    error AlreadyInit();

    /// @dev Throws if quorum exceeds `totalSupply(SIGN_KEY)`.
    error QuorumOverSupply();

    /// @dev Throws if quorum with `threshold = 0` is set.
    error InvalidThreshold();

    /// @dev Throws if `execute()` doesn't complete operation.
    error ExecuteFailed();

    /// -----------------------------------------------------------------------
    /// Keep Storage/Logic
    /// -----------------------------------------------------------------------

    /// @dev Core ID key permission.
    uint256 internal immutable CORE_KEY = uint32(type(KeepToken).interfaceId);

    /// @dev Default ERC4337 handler contract.
    address internal immutable entryPoint;

    /// @dev Default metadata fetcher for `uri()` and ERC4337 aggregation.
    address internal immutable fetcher;

    /// @dev Record of states verifying `execute()`.
    uint120 public nonce;

    /// @dev SIGN_KEY threshold to `execute()`.
    uint120 public quorum;

    /// @dev Internal ID metadata mapping.
    mapping(uint256 => string) internal _uris;

    /// @dev ID metadata fetcher.
    /// @param id ID to fetch from.
    /// @return tokenURI Metadata.
    function uri(uint256 id) public view virtual returns (string memory) {
        string memory tokenURI = _uris[id];

        if (bytes(tokenURI).length > 0) return tokenURI;
        else return Keep(fetcher).uri(id);
    }

    /// @dev Access control check for ID key balance holders.
    /// Initializes with `address(this)` having implicit permission
    /// without writing to storage by checking `totalSupply()` is zero.
    /// Otherwise, this permission can be set to additional accounts,
    /// including retaining `address(this)`, via `mint()`.
    function _authorized() internal view virtual returns (bool) {
        if (
            (totalSupply[CORE_KEY] == 0 && msg.sender == address(this)) ||
            balanceOf[msg.sender][CORE_KEY] != 0 ||
            balanceOf[msg.sender][uint32(msg.sig)] != 0
        ) return true;
        else revert Unauthorized();
    }

    /// -----------------------------------------------------------------------
    /// ERC165 Logic
    /// -----------------------------------------------------------------------

    /// @dev ERC165 interface detection.
    /// @param interfaceId ID to check.
    /// @return Fetch detection success.
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override returns (bool) {
        return
            // ERC165 Interface ID for ERC721TokenReceiver.
            interfaceId == this.onERC721Received.selector ||
            // ERC165 Interface ID for ERC1155TokenReceiver.
            interfaceId == type(ERC1155TokenReceiver).interfaceId ||
            // ERC165 Interface IDs for ERC1155.
            super.supportsInterface(interfaceId);
    }

    /// -----------------------------------------------------------------------
    /// ERC721 Receiver Logic
    /// -----------------------------------------------------------------------

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) public payable virtual returns (bytes4) {
        return this.onERC721Received.selector;
    }

    /// -----------------------------------------------------------------------
    /// Initialization Logic
    /// -----------------------------------------------------------------------

    /// @notice Create Keep template.
    /// @param _entryPoint ERC4337 handler.
    /// @param _fetcher Metadata and signature validator.
    constructor(address _entryPoint, address _fetcher) payable {
        entryPoint = _entryPoint;
        fetcher = _fetcher;

        // Deploy as singleton.
        quorum = 1;
    }

    /// @notice Initialize Keep configuration.
    /// @param calls Initial Keep operations.
    /// @param signers Initial signer set.
    /// @param threshold Initial quorum.
    function initialize(
        Call[] calldata calls,
        address[] calldata signers,
        uint256 threshold
    ) public payable virtual {
        if (quorum != 0) revert AlreadyInit();

        if (threshold == 0) revert InvalidThreshold();

        if (threshold > signers.length) revert QuorumOverSupply();

        if (calls.length != 0) {
            for (uint256 i; i < calls.length; ) {
                _execute(
                    calls[i].op,
                    calls[i].to,
                    calls[i].value,
                    calls[i].data
                );

                // An array can't have a total length
                // larger than the max uint256 value.
                unchecked {
                    ++i;
                }
            }
        }

        address previous;
        address signer;
        uint256 supply;

        for (uint256 i; i < signers.length; ) {
            signer = signers[i];

            // Prevent zero and duplicate signers.
            if (previous >= signer) revert Unauthorized();

            previous = signer;

            emit TransferSingle(tx.origin, address(0), signer, SIGN_KEY, 1);

            // An array can't have a total length
            // larger than the max uint256 value.
            unchecked {
                ++balanceOf[signer][SIGN_KEY];
                ++supply;
                ++i;
            }
        }

        totalSupply[SIGN_KEY] = supply;
        quorum = uint120(threshold);
    }

    /// -----------------------------------------------------------------------
    /// Execution Logic
    /// -----------------------------------------------------------------------

    /// @notice Execute operation from Keep with signatures.
    /// @param op Enum operation to execute.
    /// @param to Address to send operation to.
    /// @param value Amount of ETH to send in operation.
    /// @param data Payload to send in operation.
    /// @param sigs Array of Keep signatures in ascending order by addresses.
    function execute(
        Operation op,
        address to,
        uint256 value,
        bytes calldata data,
        Signature[] calldata sigs
    ) public payable virtual {
        uint120 txNonce;

        // Unchecked because the only math done is incrementing
        // Keep nonce which cannot realistically overflow.
        unchecked {
            emit Executed(txNonce = nonce++, op, to, value, data);
        }

        // Begin signature validation with hashed inputs.
        bytes32 hash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        keccak256(
                            "Execute(uint8 op,address to,uint256 value,bytes data,uint120 nonce)"
                        ),
                        op,
                        to,
                        value,
                        keccak256(data),
                        txNonce
                    )
                )
            )
        );

        // Start zero in loop to ensure ascending addresses.
        address previous;

        // Validation is length of quorum threshold.
        uint256 threshold = quorum;

        // Store outside loop for gas optimization.
        Signature calldata sig;

        for (uint256 i; i < threshold; ) {
            // Load signature items.
            sig = sigs[i];
            address user = sig.user;

            // Check SIGN_KEY balance.
            // This also confirms non-zero `user`.
            if (balanceOf[user][SIGN_KEY] == 0) revert Unauthorized();

            // Check signature recovery.
            _recoverSig(hash, user, sig.v, sig.r, sig.s);

            // Check against duplicates.
            if (previous >= user) revert Unauthorized();

            // Memo signature for next iteration until quorum.
            previous = user;

            // An array can't have a total length
            // larger than the max uint256 value.
            unchecked {
                ++i;
            }
        }

        _execute(op, to, value, data);
    }

    /// @notice Relay operation from Keep via `execute()` or as ID key holder.
    /// @param call Keep operation as struct of `op, to, value, data`.
    function relay(Call calldata call) public payable virtual {
        _authorized();

        _execute(call.op, call.to, call.value, call.data);

        emit Relayed(call);
    }

    /// @notice Relay operations from Keep via `execute()` or as ID key holder.
    /// @param calls Keep operations as struct arrays of `op, to, value, data`.
    function multirelay(Call[] calldata calls) public payable virtual {
        _authorized();

        for (uint256 i; i < calls.length; ) {
            _execute(calls[i].op, calls[i].to, calls[i].value, calls[i].data);

            // An array can't have a total length
            // larger than the max uint256 value.
            unchecked {
                ++i;
            }
        }

        emit Multirelayed(calls);
    }

    function _execute(
        Operation op,
        address to,
        uint256 value,
        bytes memory data
    ) internal virtual {
        if (op == Operation.call) {
            assembly {
                let success := call(
                    gas(),
                    to,
                    value,
                    add(data, 0x20),
                    mload(data),
                    0,
                    0
                )
                returndatacopy(0, 0, returndatasize())
                switch success
                case 0 {
                    revert(0, returndatasize())
                }
                default {
                    return(0, returndatasize())
                }
            }
        } else if (op == Operation.delegatecall) {
            assembly {
                let success := delegatecall(
                    gas(),
                    to,
                    add(data, 0x20),
                    mload(data),
                    0,
                    0
                )
                returndatacopy(0, 0, returndatasize())
                switch success
                case 0 {
                    revert(0, returndatasize())
                }
                default {
                    return(0, returndatasize())
                }
            }
        } else {
            assembly {
                if iszero(create(value, add(data, 0x20), mload(data))) {
                    revert(0, 0)
                }
            }
        }
    }

    /// -----------------------------------------------------------------------
    /// ERC1271 Logic
    /// -----------------------------------------------------------------------

    function isValidSignature(
        bytes32 hash,
        bytes memory signature
    ) public view virtual returns (bytes4) {
        if (signature.length == 65) {
            bytes32 r;
            bytes32 s;
            uint8 v;
            /// @solidity memory-safe-assembly
            assembly {
                r := mload(add(signature, 0x20))
                s := mload(add(signature, 0x40))
                v := byte(0, mload(add(signature, 0x60)))
            }

            // Check SIGN_KEY balance.
            // This also confirms non-zero `user`.
            if (balanceOf[ecrecover(hash, v, r, s)][SIGN_KEY] != 0)
                return this.isValidSignature.selector;
        } else {
            return 0xffffffff;
        }
    }

    /// -----------------------------------------------------------------------
    /// ERC4337 Logic
    /// -----------------------------------------------------------------------

    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) public payable virtual returns (uint256 validationData) {
        if (msg.sender != entryPoint) revert Unauthorized();

        if (quorum == 1) {
            bytes memory signature = userOp.signature;
            address signer;
            bytes32 hash;

            /// @solidity memory-safe-assembly
            assembly {
                mstore(0x20, userOpHash) // Store into scratch space for keccak256.
                mstore(0x00, "\x00\x00\x00\x00\x19Ethereum Signed Message:\n32") // 28 bytes.
                hash := keccak256(0x04, 0x3c) // `32 * 2 - (32 - 28) = 60 = 0x3c`.

                let m := mload(0x40) // Cache the free memory pointer.
                let signatureLength := mload(signature)
                mstore(0x00, hash)
                mstore(0x20, byte(0, mload(add(signature, 0x60)))) // `v`.
                mstore(0x40, mload(add(signature, 0x20))) // `r`.
                mstore(0x60, mload(add(signature, 0x40))) // `s`.
                signer := mload(
                    staticcall(
                        gas(), // Amount of gas left for the transaction.
                        eq(signatureLength, 65), // Address of `ecrecover`.
                        0x00, // Start of input.
                        0x80, // Size of input.
                        0x01, // Start of output.
                        0x20 // Size of output.
                    )
                )
                // `returndatasize()` will be `0x20` upon success, and `0x00` otherwise.
                if iszero(returndatasize()) {
                    mstore(0x00, 0x8baa579f) // `InvalidSignature()`.
                    revert(0x1c, 0x04)
                }
                mstore(0x60, 0) // Restore the zero slot.
                mstore(0x40, m) // Restore the free memory pointer.
            }

            // Check SIGN_KEY balance.
            // This also confirms non-zero `user`.
            balanceOf[signer][SIGN_KEY] != 0
                ? validationData = 0
                : validationData = 1;
        } else {
            validationData = uint256(uint160(fetcher));
        }

        if (missingAccountFunds != 0) {
            assembly {
                pop(call(gas(), caller(), missingAccountFunds, 0, 0, 0, 0))
            }
        }
    }

    /// -----------------------------------------------------------------------
    /// Mint/Burn Logic
    /// -----------------------------------------------------------------------

    /// @notice ID minter.
    /// @param to Recipient of mint.
    /// @param id ID to mint.
    /// @param amount ID balance to mint.
    /// @param data Optional data payload.
    function mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) public payable virtual {
        _authorized();

        _mint(to, id, amount, data);
    }

    /// @notice ID burner.
    /// @param from Account to burn from.
    /// @param id ID to burn.
    /// @param amount Balance to burn.
    function burn(
        address from,
        uint256 id,
        uint256 amount
    ) public payable virtual {
        if (msg.sender != from)
            if (!isApprovedForAll[from][msg.sender])
                if (!_authorized()) revert Unauthorized();

        _burn(from, id, amount);

        if (id == SIGN_KEY)
            if (quorum > totalSupply[SIGN_KEY]) revert QuorumOverSupply();
    }

    /// -----------------------------------------------------------------------
    /// Threshold Setting Logic
    /// -----------------------------------------------------------------------

    /// @notice Update Keep quorum threshold.
    /// @param threshold Signature threshold for `execute()`.
    function setQuorum(uint256 threshold) public payable virtual {
        _authorized();

        if (threshold == 0) revert InvalidThreshold();

        if (threshold > totalSupply[SIGN_KEY]) revert QuorumOverSupply();

        quorum = uint120(threshold);

        emit QuorumSet(threshold);
    }

    /// -----------------------------------------------------------------------
    /// ID Setting Logic
    /// -----------------------------------------------------------------------

    /// @notice ID transferability setting.
    /// @param id ID to set transferability for.
    /// @param on Transferability setting.
    function setTransferability(uint256 id, bool on) public payable virtual {
        _authorized();

        _setTransferability(id, on);
    }

    /// @notice ID transfer permission toggle.
    /// @param id ID to set permission for.
    /// @param on Permission setting.
    /// @dev This sets account-based ID restriction globally.
    function setPermission(uint256 id, bool on) public payable virtual {
        _authorized();

        _setPermission(id, on);
    }

    /// @notice ID transfer permission setting.
    /// @param to Account to set permission for.
    /// @param id ID to set permission for.
    /// @param on Permission setting.
    /// @dev This sets account-based ID restriction specifically.
    function setUserPermission(
        address to,
        uint256 id,
        bool on
    ) public payable virtual {
        _authorized();

        _setUserPermission(to, id, on);
    }

    /// @notice ID metadata setting.
    /// @param id ID to set metadata for.
    /// @param tokenURI Metadata setting.
    function setURI(
        uint256 id,
        string calldata tokenURI
    ) public payable virtual {
        _authorized();

        _uris[id] = tokenURI;

        emit URI(tokenURI, id);
    }
}
