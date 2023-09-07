// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {ERC1155TokenReceiver, KeepToken} from "./KeepToken.sol";
import {Multicallable} from "./utils/Multicallable.sol";

/// @title Keep
/// @notice Multitoken signature auth system.
/// @dev Optimized for multisig operations.
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

    /// @dev Emitted when Keep executes EXEC_KEY op.
    event Executed(
        uint256 indexed nonce,
        Operation op,
        address to,
        uint256 value,
        bytes data
    );

    /// @dev Emitted when Keep relays op.
    event Relayed(Call call);

    /// @dev Emitted when Keep relays ops.
    event Multirelayed(Call[] calls);

    /// @dev Emitted when `quorum` threshold updates.
    event QuorumSet(uint256 id, uint256 quorum);

    /// @dev Emitted when signature revoked.
    event SignatureRevoked(address indexed user, bytes32 hash);

    /// -----------------------------------------------------------------------
    /// Custom Errors
    /// -----------------------------------------------------------------------

    /// @dev Throws if `initialize()` is called more than once.
    error AlreadyInit();

    /// @dev Throws if `quorum` exceeds `totalSupply()` or is zero.
    error InvalidThreshold();

    /// -----------------------------------------------------------------------
    /// Keep Storage/Logic
    /// -----------------------------------------------------------------------

    /// @dev Core ID key permission.
    uint256 internal constant CORE_KEY = uint32(type(KeepToken).interfaceId);

    /// @dev External validation for ERC1155 `uri()` & ERC4337 permissioning.
    Keep internal immutable validator;

    /// @dev Record of states verifying `execute()`.
    uint256 public nonce;

    /// @dev Internal ID metadata mapping.
    mapping(uint256 id => string) internal _uri;

    /// @dev Internal ID signature threshold mapping.
    mapping(uint256 id => uint256) public quorum;

    /// @dev Internal signature hash revocation status.
    mapping(address user => mapping(bytes32 hash => bool)) internal revoked;

    /// @dev ERC4337 entrypoint.
    function entryPoint() public view virtual returns (address) {
        return validator.entryPoint();
    }

    /// @dev ID metadata fetcher.
    /// @param id ID to fetch from.
    /// @return tokenURI Metadata.
    function uri(uint256 id) public view virtual returns (string memory) {
        string memory tokenURI = _uri[id];

        if (bytes(tokenURI).length > 0) return tokenURI;
        else return validator.uri(id);
    }

    /// @dev Access control check for ID key holders & other auth.
    /// Initializes with `address(this)` having implicit permission
    /// without writing to storage by checking `totalSupply()` is zero.
    /// Otherwise, this permission can be set to additional accounts,
    /// including retaining `address(this)`, via `mint()`.
    function _authorized() internal view virtual returns (bool) {
        if (
            (totalSupply[CORE_KEY] == 0 && msg.sender == address(this)) ||
            msg.sender == validator.entryPoint() ||
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
    /// @return supported Status field.
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual returns (bool supported) {
        assembly ("memory-safe") {
            let s := shr(224, interfaceId)
            // ERC165: 0x01ffc9a7, ERC1155: 0xd9b67a26, ERC1155MetadataURI: 0x0e89341c,
            // ERC721TokenReceiver: 0x150b7a02, ERC1155TokenReceiver: 0x4e2312e0,
            // ERC1271: 0x1626ba7e, ERC6066: 0x12edb34f
            supported := or(
                or(or(eq(s, 0x01ffc9a7), eq(s, 0xd9b67a26)), eq(s, 0x0e89341c)),
                or(
                    or(eq(s, 0x150b7a02), eq(s, 0x4e2312e0)),
                    or(eq(s, 0x1626ba7e), eq(s, 0x12edb34f))
                )
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
    /// @param _validator ERC1155/4337 helper.
    constructor(Keep _validator) payable {
        // Set as immutable.
        validator = _validator;

        // Deploy as singleton.
        quorum[EXEC_KEY] = 999;
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
        if (quorum[EXEC_KEY] != 0) revert AlreadyInit();

        if (threshold == 0) revert InvalidThreshold();

        if (threshold > signers.length) revert InvalidThreshold();

        if (calls.length != 0) {
            for (uint256 i; i < calls.length; ) {
                // An array can't have a total length
                // larger than the max uint256 value.
                unchecked {
                    ++i;
                }

                _execute(
                    calls[i].op,
                    calls[i].to,
                    calls[i].value,
                    calls[i].data
                );
            }
        }

        address previous;
        address signer;
        uint256 supply;

        for (uint256 i; i < signers.length; ) {
            signer = signers[i];

            // Prevent zero and duplicate signers.
            if (previous >= signer) revert InvalidArray();

            previous = signer;

            emit TransferSingle(
                tx.origin,
                address(0),
                signer,
                EXEC_KEY,
                balanceOf[signer][EXEC_KEY] = 1
            );

            // An array can't have a total length
            // larger than the max uint256 value.
            unchecked {
                ++supply;
                ++i;
            }
        }

        totalSupply[EXEC_KEY] = supply;
        quorum[EXEC_KEY] = threshold;
    }

    /// -----------------------------------------------------------------------
    /// Execution Logic
    /// -----------------------------------------------------------------------

    /// @notice Execute Keep-structured operation.
    /// @param op Enum operation to execute.
    /// @param to Address to send operation to.
    /// @param value Amount of ETH to send in operation.
    /// @param data Payload to send in operation.
    /// @param sigs Ascending array of Keep signatures.
    function execute(
        Operation op,
        address to,
        uint256 value,
        bytes calldata data,
        Signature[] calldata sigs
    ) public payable virtual {
        uint256 txNonce;
        // Unchecked because the only math done is incrementing
        // Keep `nonce` which cannot realistically overflow.
        unchecked {
            emit Executed(txNonce = nonce++, op, to, value, data);
        }

        // Derive operation hash.
        bytes32 hash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        keccak256(
                            "Execute(uint8 op,address to,uint256 value,bytes data,uint256 nonce)"
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

        // Memo zero `user` for ascending order.
        address previous;
        // Memo `quorum` threshold for loop length.
        uint256 threshold = quorum[EXEC_KEY];
        // Memo signature outside loop for optimization.
        Signature calldata sig;

        // Check enough valid `sigs` to pass `quorum`.
        uint256 i;
        for (i; i < threshold; ) {
            // Load `user` details.
            sig = sigs[i];
            address user = sig.user;

            // Check EXEC_KEY balance.
            // This also confirms non-zero `user`.
            if (balanceOf[user][EXEC_KEY] == 0) revert Unauthorized();

            // Check `user` `sig` recovery for `hash`.
            _checkSig(user, hash, sig.v, sig.r, sig.s);

            // Check for `user` duplicates.
            if (previous >= user) revert InvalidArray();

            // Memo `user` for next loop until `quorum`.
            previous = user;

            // An array can't have a total length
            // larger than the max uint256 value.
            unchecked {
                ++i;
            }
        }

        _execute(op, to, value, data);
    }

    /// @notice Relay op from Keep `execute()` or as `authorized()`.
    /// @param call Keep op as struct of `op, to, value, data`.
    function relay(Call calldata call) public payable virtual {
        _authorized();

        emit Relayed(call);

        _execute(call.op, call.to, call.value, call.data);
    }

    /// @notice Relay ops from Keep `execute()` or as `authorized()`.
    /// @param calls Keep ops as struct arrays of `op, to, value, data`.
    function multirelay(Call[] calldata calls) public payable virtual {
        _authorized();

        uint256 i;
        for (i; i < calls.length; ) {
            // An array can't have a total length
            // larger than the max uint256 value.
            unchecked {
                ++i;
            }

            _execute(calls[i].op, calls[i].to, calls[i].value, calls[i].data);
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
                    gas(),
                    0x00
                )
                returndatacopy(0x00, 0x00, returndatasize())
                if iszero(success) {
                    revert(0x00, returndatasize())
                }
                return(0x00, returndatasize())
            }
        } else if (op == Operation.delegatecall) {
            assembly {
                let success := delegatecall(
                    gas(),
                    to,
                    add(data, 0x20),
                    mload(data),
                    gas(),
                    0x00
                )
                returndatacopy(0x00, 0x00, returndatasize())
                if iszero(success) {
                    revert(0x00, returndatasize())
                }
                return(0x00, returndatasize())
            }
        } else if (op == Operation.create) {
            assembly {
                let created := create(value, add(data, 0x20), mload(data))
                if iszero(created) {
                    revert(0x00, 0x00)
                }
                mstore(0x00, created)
                return(0x00, 0x20)
            }
        } else {
            assembly {
                let created := create2(
                    value,
                    add(add(data, 0x20), 0x20),
                    sub(mload(data), 0x20),
                    mload(add(data, 0x20))
                )
                if iszero(created) {
                    revert(0x00, 0x00)
                }
                mstore(0x00, created)
                return(0x00, 0x20)
            }
        }
    }

    /// -----------------------------------------------------------------------
    /// Revocation Logic
    /// -----------------------------------------------------------------------

    /// @notice Signature revocation.
    /// @param hash Signed data hash.
    /// @param sig Keep-structured sig.
    function revokeSignature(
        bytes32 hash,
        Signature calldata sig
    ) public payable virtual {
        _checkSig(sig.user, hash, sig.v, sig.r, sig.s);

        revoked[sig.user][hash] = true;

        emit SignatureRevoked(sig.user, hash);
    }

    /// -----------------------------------------------------------------------
    /// ERC1271 Logic
    /// -----------------------------------------------------------------------

    function isValidSignature(
        bytes32 hash,
        bytes calldata sig
    ) public view virtual returns (bytes4) {
        // Check `EXEC_KEY` as this denotes Keep ownership.
        if (_validate(hash, sig, EXEC_KEY) == 0) return 0x1626ba7e;
        else return 0xffffffff;
    }

    /// -----------------------------------------------------------------------
    /// ERC6066 Logic
    /// -----------------------------------------------------------------------

    /// @param id ID of signing NFT.
    /// @param hash Signed data hash.
    /// @param sig Signature payload.
    function isValidSignature(
        uint256 id,
        bytes32 hash,
        bytes calldata sig
    ) public view virtual returns (bytes4) {
        if (_validate(hash, sig, id) == 0) return 0x12edb34f;
        else return 0xffffffff;
    }

    /// -----------------------------------------------------------------------
    /// ERC4337 Logic
    /// -----------------------------------------------------------------------

    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) public payable virtual returns (uint256 validationData) {
        // Check request comes from `entrypoint()`.
        if (msg.sender != validator.entryPoint()) revert Unauthorized();

        // Build ERC191-structured `userOpHash`.
        assembly ("memory-safe") {
            mstore(0x20, userOpHash) // Store into scratch space for keccak256.
            mstore(0x00, "\x00\x00\x00\x00\x19Ethereum Signed Message:\n32") // 28 bytes.
            userOpHash := keccak256(0x04, 0x3c) // `32 * 2 - (32 - 28) = 60 = 0x3c`.
        }

        // Shift `userOp.nonce` to get ID key.
        uint256 key = (userOp.nonce >> 64);
        uint256 id = key >> 191;

        // Check signature `quorum` is met and validate auth.
        validationData = _validate(userOpHash, userOp.signature, id);

        // Extract 'validator flag' in 192rd bit. If set, `validator` check `userOp` with `id`.
        if ((key & (1 << 191)) != 0)
            validationData = validator.validateUserOp(userOp, userOpHash, id);

        // Send any missing funds to `entrypoint()` (msg.sender).
        if (missingAccountFunds != 0)
            assembly {
                pop(
                    call(
                        gas(),
                        caller(),
                        missingAccountFunds,
                        gas(),
                        0x00,
                        gas(),
                        0x00
                    )
                )
            }
    }

    function _validate(
        bytes32 hash,
        bytes calldata sig,
        uint256 id
    ) internal view virtual returns (uint256 validationData) {
        address user;
        uint256 threshold = quorum[id];

        // Return invalid if inactive.
        if (threshold == 0) return 1;

        // Return early for single `sig`.
        if (threshold == 1) {
            (user, validationData) = _validateSig(hash, sig);

            if (validationData == 1) return 1;

            if (revoked[user][hash]) return 1;

            return balanceOf[user][id] != 0 ? 0 : 1;
        }

        // Memo split `sig` into `sigs`.
        bytes[] memory sigs = _splitSigs(sig);
        // Memo zero `user` for ascending order.
        address previous;

        // Check enough valid `sigs` to pass `quorum`.
        uint256 i;
        for (i; i < threshold; ) {
            (user, validationData) = _validateSig(hash, sigs[i]);

            if (validationData == 1) return 1;

            if (revoked[user][hash]) return 1;

            // Check for `user` duplicates.
            if (previous >= user) return 1;

            // Memo `user` for next loop until `quorum`.
            previous = user;

            // If not keyholding `user`, `SIG_VALIDATION_FAILED`.
            if (balanceOf[user][id] == 0) return 1;

            // An array can't have a total length
            // larger than the max uint256 value.
            unchecked {
                ++i;
            }
        }

        return 0;
    }

    function _validateSig(
        bytes32 hash,
        bytes memory sig
    ) internal view virtual returns (address user, uint256 validationData) {
        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly ("memory-safe") {
            r := mload(add(sig, 0x20))
            s := mload(add(sig, 0x40))
            v := byte(0x00, mload(add(sig, 0x60)))
        }

        // Check `v` to branch ecrecover or ERC1271.
        if (v != 0) {
            assembly ("memory-safe") {
                let m := mload(0x40) // Cache the free memory pointer.
                mstore(0x00, hash)
                mstore(0x20, and(v, 0xff))
                mstore(0x40, r)
                mstore(0x60, s)
                user := mload(
                    staticcall(
                        gas(), // Amount of gas left for the transaction.
                        1, // Address of `ecrecover`.
                        0x00, // Start of input.
                        0x80, // Size of input.
                        0x01, // Start of output.
                        0x20 // Size of output.
                    )
                )
                mstore(0x60, 0x00) // Restore the zero slot.
                mstore(0x40, m) // Restore the free memory pointer.
            }
        } else {
            // Derive `user` from `r`.
            user = address(uint160(uint256(r)));

            assembly ("memory-safe") {
                let m := mload(0x40)
                let f := shl(224, 0x1626ba7e)
                mstore(m, f) // `bytes4(keccak256("isValidSignature(bytes32,bytes)"))`.
                mstore(add(m, 0x04), hash)
                let d := add(m, 0x24)
                mstore(d, 0x40) // The offset of the `signature` in the calldata.
                mstore(add(m, 0x44), 65) // Length of the signature.
                mstore(add(m, 0x64), r) // `r`.
                mstore(add(m, 0x84), s) // `s`.
                mstore8(add(m, 0xa4), v) // `v`.

                if iszero(
                    and(
                        // Whether the returndata is the magic value `0x1626ba7e` (left-aligned).
                        eq(mload(d), f),
                        // Whether the staticcall does not revert.
                        // This must be placed at the end of the `and` clause,
                        // as the arguments are evaluated from right to left.
                        staticcall(
                            gas(), // Remaining gas.
                            user, // The `user` address.
                            m, // Offset of calldata in memory.
                            0xa5, // Length of calldata in memory.
                            d, // Offset of returndata.
                            0x20 // Length of returndata to write.
                        )
                    )
                ) {
                    validationData := 1
                }
            }
        }
    }

    function _splitSigs(
        bytes memory sig
    ) internal pure virtual returns (bytes[] memory sigs) {
        // todo: check memsafe
        assembly {
            // Check if `sig.length % 65 == 0`.
            if iszero(eq(mod(mload(sig), 65), 0x00)) {
                // If not, revert with InvalidSignature.
                mstore(0x00, 0x8baa579f) // `InvalidSignature()`.
                revert(0x1c, 0x04)
            }

            // Calculate count in assembly.
            let count := div(mload(sig), 65)

            // Allocate memory for split array.
            sigs := mload(0x40) // Current free memory pointer (using mload(0x40) instead of msize).
            mstore(sigs, count) // Store length of the sigs array.

            let sigPtr := add(sig, 0x20) // Pointer to start of `sig` data.
            let splitDataPtr := add(sigs, 0x20) // Pointer to data section of `sigs` array.

            for {
                let i := 0
            } lt(i, count) {
                i := add(i, 1)
            } {
                let m := mload(0x40) // Cache free memory pointer.

                // Store pointer to new memory in `sigs` array's data section.
                mstore(splitDataPtr, m)

                // Store length and data for the `sig`.
                mstore(m, 65)
                mstore(add(m, 0x20), mload(sigPtr))
                mstore(add(m, 0x40), mload(add(sigPtr, 0x20)))
                mstore8(add(m, 0x60), mload(add(sigPtr, 0x40)))

                // Move the pointers for the next iteration.
                mstore(0x40, add(m, 0x61)) // Update free memory pointer.
                sigPtr := add(sigPtr, 65) // Move to next `sig`.
                splitDataPtr := add(splitDataPtr, 0x20) // Move to next position.
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

        if (id == EXEC_KEY)
            if (quorum[EXEC_KEY] > totalSupply[EXEC_KEY])
                revert InvalidThreshold();
    }

    /// -----------------------------------------------------------------------
    /// Threshold Setting Logic
    /// -----------------------------------------------------------------------

    /// @notice Update Keep ID quorum threshold.
    /// @param id ID key to set quorum threshold for.
    /// @param threshold Signature threshold for quorum.
    function setQuorum(uint256 id, uint256 threshold) public payable virtual {
        _authorized();

        if (threshold == 0) revert InvalidThreshold();

        if (threshold > totalSupply[id]) revert InvalidThreshold();

        quorum[id] = threshold;

        emit QuorumSet(id, threshold);
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

        _uri[id] = tokenURI;

        emit URI(tokenURI, id);
    }
}
