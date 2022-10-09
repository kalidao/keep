// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {ERC1155TokenReceiver, KeepToken} from "./KeepToken.sol";
import {Multicallable} from "./utils/Multicallable.sol";

/// @title Keep
/// @notice Tokenized multisig wallet.
/// @author z0r0z.eth
/// @custom:coauthor boredretard.eth
/// @custom:coauthor vectorized.eth
/// @custom:coauthor shivanshi.eth
/// @custom:coauthor @0xAlcibiades
/// @custom:coauthor @0xmichalis
/// @custom:coauthor @m1guelpf
/// @custom:coauthor @asnared
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

contract Keep is ERC1155TokenReceiver, KeepToken, Multicallable {
    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    /// @dev Emitted when Keep executes call.
    event Executed(Operation op, address indexed to, uint256 value, bytes data);

    /// @dev Emitted when Keep creates contract.
    event ContractCreated(
        Operation op,
        address indexed creation,
        uint256 value
    );

    /// @dev Emitted when quorum threshold is updated.
    event QuorumSet(address indexed operator, uint256 threshold);

    /// -----------------------------------------------------------------------
    /// Custom Errors
    /// -----------------------------------------------------------------------

    /// @dev Throws if `initialize()` is called more than once.
    error AlreadyInit();

    /// @dev Throws if quorum exceeds `totalSupply(EXECUTE_ID)`.
    error QuorumOverSupply();

    /// @dev Throws if `execute()` doesn't complete operation.
    error ExecuteFailed();

    /// -----------------------------------------------------------------------
    /// Keep Storage/Logic
    /// -----------------------------------------------------------------------

    /// @dev The number which `s` must not exceed in order for
    /// the signature to be non-malleable.
    bytes32 internal constant MALLEABILITY_THRESHOLD =
        0x7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0;

    /// @dev Core ID key permission.
    uint256 internal immutable CORE_ID = uint32(uint160(address(this)));

    /// @dev Default metadata fetcher for `uri()`.
    Keep internal immutable uriFetcher;

    /// @dev Record of states verifying `execute()`.
    uint96 public nonce;

    /// @dev EXECUTE_ID threshold to `execute()`.
    uint96 public quorum;

    /// @dev Internal ID metadata mapping.
    mapping(uint256 => string) internal _uris;

    /// @dev ID metadata fetcher.
    /// @param id ID to fetch from.
    /// @return tokenURI Metadata.
    function uri(uint256 id)
        public
        view
        virtual
        override
        returns (string memory tokenURI)
    {
        tokenURI = _uris[id];

        if (bytes(tokenURI).length != 0) return tokenURI;
        else return uriFetcher.uri(id);
    }

    /// @dev The immutable name of this Keep.
    /// @return Name string.
    function name() public pure virtual returns (string memory) {
        return string(abi.encodePacked(_computeArgUint256(2)));
    }

    /// @dev Access control check for ID key balance holders.
    function _authorized() internal view virtual returns (bool) {
        if (_coreKeyHolder() || balanceOf[msg.sender][uint32(msg.sig)] != 0)
            return true;
        else revert NotAuthorized();
    }

    /// @dev Core access control check.
    /// Initalizes with `address(this)` having implicit permission
    /// without writing to storage by checking `totalSupply()` is zero.
    /// Otherwise, this permission can be set to additional accounts,
    /// including retaining `address(this)`, via `mint()`.
    function _coreKeyHolder() internal view virtual returns (bool) {
        return
            (totalSupply[CORE_ID] == 0 && msg.sender == address(this)) ||
            balanceOf[msg.sender][CORE_ID] != 0;
    }

    /// -----------------------------------------------------------------------
    /// ERC165 Logic
    /// -----------------------------------------------------------------------

    /// @dev ERC165 interface detection.
    /// @param interfaceId ID to check.
    /// @return Fetch detection success.
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override
        returns (bool)
    {
        return
            interfaceId == this.onERC721Received.selector || // ERC165 Interface ID for ERC721TokenReceiver.
            interfaceId == type(ERC1155TokenReceiver).interfaceId || // ERC165 Interface ID for ERC1155TokenReceiver.
            super.supportsInterface(interfaceId); // ERC165 Interface IDs for ERC1155.
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
    /// @param _uriFetcher Metadata default.
    constructor(Keep _uriFetcher) payable {
        uriFetcher = _uriFetcher;
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

        assembly {
            if iszero(threshold) {
                revert(0, 0)
            }
        }

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
            if (previous >= signer) revert InvalidSig();

            previous = signer;

            // Won't realistically overflow.
            unchecked {
                ++balanceOf[signer][EXECUTE_ID];
                ++supply;
                ++i;
            }

            // We don't call `_moveDelegates()` to save deployment gas.
            emit TransferSingle(msg.sender, address(0), signer, EXECUTE_ID, 1);
        }

        quorum = uint96(threshold);

        totalSupply[EXECUTE_ID] = supply;

        KeepToken._initialize();
    }

    /// -----------------------------------------------------------------------
    /// Execution Logic
    /// -----------------------------------------------------------------------

    /// @notice Execute operation from Keep with signatures.
    /// @param op Enum operation to execute.
    /// @param to Address to send operation to.
    /// @param value Amount of ETH to send in operation.
    /// @param data Payload to send in operation.
    /// @param sigs Array of Keep signatures sorted in ascending order by addresses.
    /// @dev Make sure signatures are sorted in ascending order - otherwise verification will fail.
    /// @return success Fetch whether operation succeeded.
    function execute(
        Operation op,
        address to,
        uint256 value,
        bytes calldata data,
        Signature[] calldata sigs
    ) public payable virtual returns (bool success) {
        // Begin signature validation with payload hash.
        bytes32 hash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        keccak256(
                            "Execute(Operation op,address to,uint256 value,bytes data,uint256 nonce)"
                        ),
                        op,
                        to,
                        value,
                        data,
                        nonce
                    )
                )
            )
        );

        // Start from zero in loop to ensure ascending addresses.
        address previous;

        // Validation is length of quorum threshold.
        uint256 threshold = quorum;

        // Store outside loop for gas optimization.
        Signature memory sig;

        for (uint256 i; i < threshold; ) {
            // Load signature items.
            sig = sigs[i];
            address user = sig.user;

            // Check signature recovery.
            _checkSigRecovery(hash, user, sig.v, sig.r, sig.s);

            // Check EXECUTE_ID balance.
            if (balanceOf[user][EXECUTE_ID] == 0) revert InvalidSig();

            // Check duplicates.
            if (previous >= user) revert InvalidSig();

            // Memo signer for next iteration until quorum.
            previous = user;

            // An array can't have a total length
            // larger than the max uint256 value.
            unchecked {
                ++i;
            }
        }

        success = _execute(op, to, value, data);
    }

    function _checkSigRecovery(
        bytes32 hash,
        address user,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal view virtual {
        address signer;

        assembly {
            // Copy the free memory pointer so that we can restore it later.
            let m := mload(0x40)

            // If `s` in lower half order, such that the signature is not malleable.
            if iszero(gt(s, MALLEABILITY_THRESHOLD)) {
                mstore(0x00, hash)
                mstore(0x20, v)
                mstore(0x40, r)
                mstore(0x60, s)
                pop(
                    staticcall(
                        gas(), // Amount of gas left for the transaction.
                        0x01, // Address of `ecrecover`.
                        0x00, // Start of input.
                        0x80, // Size of input.
                        0x40, // Start of output.
                        0x20 // Size of output.
                    )
                )
                // Restore the zero slot.
                mstore(0x60, 0)
                // `returndatasize()` will be `0x20` upon success, and `0x00` otherwise.
                signer := mload(sub(0x60, returndatasize()))
            }
            // Restore the free memory pointer.
            mstore(0x40, m)
        }

        if (user != signer) {
            bool valid;

            assembly {
                // Load the free memory pointer.
                // Simply using the free memory usually costs less if many slots are needed.
                let m := mload(0x40)

                // `bytes4(keccak256("isValidSignature(bytes32,bytes)"))`.
                let f := shl(224, 0x1626ba7e)
                // Write the abi-encoded calldata into memory, beginning with the function selector.
                mstore(m, f) // `bytes4(keccak256("isValidSignature(bytes32,bytes)"))`.
                mstore(add(m, 0x04), hash)
                mstore(add(m, 0x24), 0x40) // The offset of the `signature` in the calldata.
                mstore(add(m, 0x44), 65) // Store the length of the signature.
                mstore(add(m, 0x64), r) // Store `r` of the signature.
                mstore(add(m, 0x84), s) // Store `s` of the signature.
                mstore8(add(m, 0xa4), v) // Store `v` of the signature.

                valid := and(
                    and(
                        // Whether the returndata is the magic value `0x1626ba7e` (left-aligned).
                        eq(mload(0x00), f),
                        // Whether the returndata is exactly 0x20 bytes (1 word) long .
                        eq(returndatasize(), 0x20)
                    ),
                    // Whether the staticcall does not revert.
                    // This must be placed at the end of the `and` clause,
                    // as the arguments are evaluated from right to left.
                    staticcall(
                        gas(), // Remaining gas.
                        user, // The `user` address.
                        m, // Offset of calldata in memory.
                        0xa5, // Length of calldata in memory.
                        0x00, // Offset of returndata.
                        0x20 // Length of returndata to write.
                    )
                )
            }

            if (!valid) revert InvalidSig();
        }
    }

    /// @notice Execute operations from Keep with `execute()` or as key holder.
    /// @param calls Keep operations as arrays of `op, to, value, data`.
    /// @return successes Fetches whether operations succeeded.
    function multiExecute(Call[] calldata calls)
        public
        payable
        virtual
        returns (bool[] memory successes)
    {
        _authorized();

        successes = new bool[](calls.length);

        for (uint256 i; i < calls.length; ) {
            successes[i] = _execute(
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

    function _execute(
        Operation op,
        address to,
        uint256 value,
        bytes memory data
    ) internal virtual returns (bool success) {
        // Unchecked because the only math done is incrementing
        // Keep nonce which cannot realistically overflow.
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

            if (!success) revert ExecuteFailed();

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

            if (!success) revert ExecuteFailed();

            emit Executed(op, to, value, data);
        } else if (op == Operation.create) {
            address creation;

            assembly {
                creation := create(value, add(data, 0x20), mload(data))
            }

            if (creation == address(0)) revert ExecuteFailed();

            emit ContractCreated(op, creation, value);
        } else {
            address creation;
            bytes32 salt = bytes32(uint256(nonce));

            assembly {
                creation := create2(value, add(0x20, data), mload(data), salt)
            }

            if (creation == address(0)) revert ExecuteFailed();

            emit ContractCreated(op, creation, value);
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
        if (
            msg.sender != from &&
            !isApprovedForAll[from][msg.sender] &&
            !_authorized()
        ) revert NotAuthorized();

        _burn(from, id, amount);

        if (id == EXECUTE_ID)
            if (quorum > totalSupply[EXECUTE_ID]) revert QuorumOverSupply();
    }

    /// -----------------------------------------------------------------------
    /// Threshold Setting Logic
    /// -----------------------------------------------------------------------

    /// @notice Update Keep quorum threshold.
    /// @param threshold Signature threshold for `execute()`.
    function setQuorum(uint256 threshold) public payable virtual {
        _authorized();

        assembly {
            if iszero(threshold) {
                revert(0, 0)
            }
        }

        // Note: Make sure signers don't concentrate ID keys,
        // as this could cause issues in reaching quorum.
        if (threshold > totalSupply[EXECUTE_ID]) revert QuorumOverSupply();

        quorum = uint96(threshold);

        emit QuorumSet(msg.sender, threshold);
    }

    /// -----------------------------------------------------------------------
    /// ID Setting Logic
    /// -----------------------------------------------------------------------

    /// @notice ID transferability setter.
    /// @param id ID to set transferability for.
    /// @param transferability Transferability setting.
    function setTransferability(uint256 id, bool transferability)
        public
        payable
        virtual
    {
        _authorized();

        _setTransferability(id, transferability);
    }

    /// @notice ID transfer permission toggle.
    /// @param id ID to set permission for.
    /// @param set Permission setting.
    /// @dev This sets account-based ID restriction globally.
    function setPermission(uint256 id, bool set) public payable virtual {
        _authorized();

        _setPermission(id, set);
    }

    /// @notice ID transfer permission setting.
    /// @param to Account to set permission for.
    /// @param id ID to set permission for.
    /// @param set Permission setting.
    /// @dev This sets account-based ID restriction specifically.
    function setUserPermission(
        address to,
        uint256 id,
        bool set
    ) public payable virtual {
        _authorized();

        _setUserPermission(to, id, set);
    }

    /// @notice ID metadata setter.
    /// @param id ID to set metadata for.
    /// @param tokenURI Metadata setting.
    function setURI(uint256 id, string calldata tokenURI)
        public
        payable
        virtual
    {
        _authorized();

        _uris[id] = tokenURI;

        emit URI(tokenURI, id);
    }
}
