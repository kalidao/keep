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

    /**
     * Return value in case of signature failure, with no time-range.
     * Equivalent to _packValidationData(true,0,0).
     */
    uint256 internal constant SIG_VALIDATION_FAILED = 1;

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
    /// @return result Fetch detection success.
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual returns (bool result) {
        /// @solidity memory-safe-assembly
        assembly {
            let s := shr(224, interfaceId)
            // ERC165: 0x01ffc9a7, ERC1155: 0xd9b67a26, ERC1155MetadataURI: 0x0e89341c,
            // ERC721TokenReceiver: 0x150b7a02, ERC1155TokenReceiver: 0x4e2312e0
            result := or(
                or(
                    or(
                        or(eq(s, 0x01ffc9a7), eq(s, 0xd9b67a26)),
                        eq(s, 0x0e89341c)
                    ),
                    eq(s, 0x150b7a02)
                ),
                eq(s, 0x4e2312e0)
            )
        }
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

        // @TODO we don't need to verify signatures here since its validated in the validate function
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
        _authorized(); // @TODO check if from entry point

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
            /// @solidity memory-safe-assembly
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
            /// @solidity memory-safe-assembly
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
            /// @solidity memory-safe-assembly
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
        }

        return 0xffffffff;
    }

    /// -----------------------------------------------------------------------
    /// ERC4337 Logic
    /// -----------------------------------------------------------------------

    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) public payable virtual returns (uint256 validationData) {
        _requireFromEntryPoint();
        validationData = _validateSignatures(userOp, userOpHash);
        // _validateNonce(userOp.nonce);
        _payPrefund(missingAccountFunds);
    }

    /**
     * Ensure the request comes from the known entrypoint.
     */
    function _requireFromEntryPoint() internal view virtual {
        if (msg.sender != entryPoint) revert Unauthorized();
    }

    /**
     * @dev Returns the keccak256 digest of an EIP-191 signed data with version
     * `0x45` (`personal_sign` messages).
     *
     * The digest is calculated by prefixing a bytes32 `messageHash` with
     * `"\x19Ethereum Signed Message:\n32"` and hashing the result. It corresponds with the
     * hash signed when using the https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`] JSON-RPC method.
     *
     * NOTE: The `hash` parameter is intended to be the result of hashing a raw message with
     * keccak256, although any bytes32 value can be safely used because the final digest will
     * be re-hashed.
     *
     * See {ECDSA-recover}.
     */
    function _toEthSignedMessageHash(
        bytes32 messageHash
    ) internal pure returns (bytes32 digest) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, "\x19Ethereum Signed Message:\n32") // 32 is the bytes-length of messageHash
            mstore(0x1c, messageHash) // 0x1c (28) is the length of the prefix
            digest := keccak256(0x00, 0x3c) // 0x3c is the length of the prefix (0x1c) + messageHash (0x20)
        }
    }

    function _splitSigs(
        bytes memory signatures
    ) internal pure returns (bytes[] memory) {
        require(
            signatures.length % 65 == 0,
            "Signatures length must be multiple of 65"
        );

        uint256 signaturesCount = signatures.length / 65;
        bytes[] memory split = new bytes[](signaturesCount);

        unchecked {
            for (uint256 i; i < signaturesCount; ++i) {
                bytes memory signature = new bytes(65);

                for (uint256 j; j < 65; ++j) {
                    signature[j] = signatures[(i * 65) + j];
                }

                split[i] = signature;
            }
        }

        return split;
    }

    /**
     * Validate the signature is valid for this message.
     * @param userOp          - Validate the userOp.signature field.
     * @param userOpHash      - Convenient field: the hash of the request, to check the signature against.
     *                          (also hashes the entrypoint and chain id)
     * @return validationData - Signature and time-range of this operation.
     *                          <20-byte> sigAuthorizer - 0 for valid signature, 1 to mark signature failure,
     *                              otherwise, an address of an "authorizer" contract.
     *                          <6-byte> validUntil - last timestamp this operation is valid. 0 for "indefinite"
     *                          <6-byte> validAfter - first timestamp this operation is valid
     *                          If the account doesn't use time-range, it is enough to return
     *                          SIG_VALIDATION_FAILED value (1) for signature failure.
     *                          Note that the validation code cannot use block.timestamp (or block.number) directly.
     */
    function _validateSignatures(
        UserOperation calldata userOp,
        bytes32 userOpHash
    ) internal virtual returns (uint256 validationData) {
        bytes32 hash = _toEthSignedMessageHash(userOpHash);
        bytes[] memory sigs = _splitSigs(userOp.signature);

        // check we have enough valid signatures to pass the quorum
        for (uint256 i = 0; i <= quorum; i++) {
            address signer = _recoverSigner(hash, sigs[i]);
            if (balanceOf[signer][SIGN_KEY] != 0) {
                return SIG_VALIDATION_FAILED;
            }
        }

        return 0;
    }

    /**
     * Validate the nonce of the UserOperation.
     * This method may validate the nonce requirement of this account.
     * e.g.
     * To limit the nonce to use sequenced UserOps only (no "out of order" UserOps):
     *      `require(nonce < type(uint64).max)`
     * For a hypothetical account that *requires* the nonce to be out-of-order:
     *      `require(nonce & type(uint64).max == 0)`
     *
     * The actual nonce uniqueness is managed by the EntryPoint, and thus no other
     * action is needed by the account itself.
     *
     * @param _nonce to validate
     */
    // function _validateNonce(uint256 _nonce) internal view virtual {
    //     require(_nonce & type(uint64).max == 0);
    // }

    /**
     * Sends to the entrypoint (msg.sender) the missing funds for this transaction.
     * SubClass MAY override this method for better funds management
     * (e.g. send to the entryPoint more than the minimum required, so that in future transactions
     * it will not be required to send again).
     * @param missingAccountFunds - The minimum value this method should send the entrypoint.
     *                              This value MAY be zero, in case there is enough deposit,
     *                              or the userOp has a paymaster.
     */
    function _payPrefund(uint256 missingAccountFunds) internal virtual {
        if (missingAccountFunds != 0) {
            assembly {
                pop(call(gas(), caller(), missingAccountFunds, 0, 0, 0, 0))
            }
        }
    }

    function _recoverSigner(
        bytes32 hash,
        bytes memory signature
    ) internal virtual returns (address signer) {
        /// @solidity memory-safe-assembly
        assembly {
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
