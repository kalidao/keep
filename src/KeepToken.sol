// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice ERC1155 interface to receive tokens.
/// @author Modified from Solbase (https://github.com/Sol-DAO/solbase/blob/main/src/tokens/ERC1155/ERC1155.sol)
abstract contract ERC1155TokenReceiver {
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) public payable virtual returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) public payable virtual returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }
}

/// @notice Modern, minimalist, and gas-optimized ERC1155V implementation with Compound-style voting and default non-transferability.
/// @author Modified from Solbase (https://github.com/Sol-DAO/solbase/blob/main/src/tokens/ERC1155/ERC1155.sol)
/// @author Modified from Compound (https://github.com/compound-finance/compound-protocol/blob/master/contracts/Governance/Comp.sol)
/// @author Modified from OpenZeppelin (https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/extensions/ERC20Votes.sol)
contract KeepToken {
    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event DelegateChanged(
        address indexed delegator,
        address indexed fromDelegate,
        address indexed toDelegate,
        uint256 id
    );

    event DelegateVotesChanged(
        address indexed delegate,
        uint256 indexed id,
        uint256 previousBalance,
        uint256 newBalance
    );

    event TransferSingle(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 id,
        uint256 amount
    );

    event TransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] amounts
    );

    event ApprovalForAll(
        address indexed owner,
        address indexed operator,
        bool approved
    );

    event TransferabilitySet(
        address indexed operator,
        uint256 indexed id,
        bool set
    );

    event PermissionSet(address indexed operator, uint256 id, bool set);

    event UserPermissionSet(
        address indexed operator,
        address indexed to,
        uint256 id,
        bool set
    );

    event URI(string value, uint256 indexed id);

    /// -----------------------------------------------------------------------
    /// Custom Errors
    /// -----------------------------------------------------------------------

    error LengthMismatch();

    error NotAuthorized();

    error NonTransferable();

    error NotPermitted();

    error UnsafeRecipient();

    error InvalidRecipient();

    error ExpiredSig();

    error InvalidSig();

    error Undetermined();

    error Overflow();

    /// -----------------------------------------------------------------------
    /// ERC1155 Storage
    /// -----------------------------------------------------------------------

    mapping(address => mapping(uint256 => uint256)) public balanceOf;

    mapping(address => mapping(address => bool)) public isApprovedForAll;

    /// -----------------------------------------------------------------------
    /// EIP-712 Storage/Logic
    /// -----------------------------------------------------------------------

    bytes32 internal _initialDomainSeparator;

    mapping(address => uint256) public nonces;

    function DOMAIN_SEPARATOR() public view virtual returns (bytes32) {
        return
            block.chainid == _initialChainId()
                ? _initialDomainSeparator
                : _computeDomainSeparator();
    }

    function _initialChainId() internal pure virtual returns (uint256) {
        return _computeArgUint256(7);
    }

    function _computeDomainSeparator() internal view virtual returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    keccak256(
                        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                    ),
                    keccak256(bytes("Keep")),
                    keccak256("1"),
                    block.chainid,
                    address(this)
                )
            );
    }

    function _computeArgUint256(uint256 argOffset)
        internal
        pure
        returns (uint256 arg)
    {
        uint256 offset;

        assembly {
            offset := sub(
                calldatasize(),
                add(shr(240, calldataload(sub(calldatasize(), 2))), 2)
            )

            arg := calldataload(add(offset, argOffset))
        }
    }

    /// -----------------------------------------------------------------------
    /// Voting Storage
    /// -----------------------------------------------------------------------

    mapping(uint256 => uint256) public totalSupply;

    mapping(uint256 => bool) public transferable;

    mapping(uint256 => bool) public permissioned;

    mapping(address => mapping(uint256 => bool)) public userPermissioned;

    mapping(address => mapping(uint256 => address)) internal _delegates;

    mapping(address => mapping(uint256 => Checkpoint[])) public checkpoints;

    mapping(uint256 => Checkpoint[]) public totalSupplyCheckpoints;

    struct Checkpoint {
        uint40 fromTimestamp;
        uint216 votes;
    }

    /// -----------------------------------------------------------------------
    /// Metadata Logic
    /// -----------------------------------------------------------------------

    //function uri(uint256 id) public view virtual returns (string memory);

    /// -----------------------------------------------------------------------
    /// ERC165 Logic
    /// -----------------------------------------------------------------------

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        returns (bool)
    {
        return
            interfaceId == this.supportsInterface.selector || // ERC165 interface ID for ERC165.
            interfaceId == 0xd9b67a26 || // ERC165 interface ID for ERC1155.
            interfaceId == 0x0e89341c; // ERC165 interface ID for ERC1155MetadataURI.
    }

    /// -----------------------------------------------------------------------
    /// Initialization Logic
    /// -----------------------------------------------------------------------

    function _initialize() internal {
        _initialDomainSeparator = _computeDomainSeparator();
    }

    /// -----------------------------------------------------------------------
    /// ERC1155 Logic
    /// -----------------------------------------------------------------------

    function balanceOfBatch(address[] calldata owners, uint256[] calldata ids)
        public
        view
        virtual
        returns (uint256[] memory balances)
    {
        if (owners.length != ids.length) revert LengthMismatch();

        balances = new uint256[](owners.length);

        for (uint256 i; i < owners.length; ) {
            balances[i] = balanceOf[owners[i]][ids[i]];

            // Unchecked because the only math done is incrementing
            // the array index counter which cannot possibly overflow.
            unchecked {
                ++i;
            }
        }
    }

    function setApprovalForAll(address operator, bool approved)
        public
        payable
        virtual
    {
        isApprovedForAll[msg.sender][operator] = approved;

        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) public payable virtual {
        if (msg.sender != from && !isApprovedForAll[from][msg.sender])
            revert NotAuthorized();

        if (!transferable[id]) revert NonTransferable();

        if (permissioned[id]) {
            if (!userPermissioned[from][id] || !userPermissioned[to][id])
                revert NotPermitted();
        }

        balanceOf[from][id] -= amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to][id] += amount;
        }

        emit TransferSingle(msg.sender, from, to, id, amount);

        if (to.code.length != 0) {
            if (
                ERC1155TokenReceiver(to).onERC1155Received(
                    msg.sender,
                    from,
                    id,
                    amount,
                    data
                ) != ERC1155TokenReceiver.onERC1155Received.selector
            ) {
                revert UnsafeRecipient();
            }
        } else {
            if (to == address(0)) {
                revert InvalidRecipient();
            }
        }

        _moveVotingPower(delegates(from, id), delegates(to, id), id, amount);
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) public payable virtual {
        if (ids.length != amounts.length) revert LengthMismatch();

        if (msg.sender != from && !isApprovedForAll[from][msg.sender])
            revert NotAuthorized();

        // Storing these outside the loop saves ~15 gas per iteration.
        uint256 id;
        uint256 amount;

        for (uint256 i; i < ids.length; ) {
            id = ids[i];
            amount = amounts[i];

            if (!transferable[id]) revert NonTransferable();

            if (permissioned[id]) {
                if (!userPermissioned[from][id] || !userPermissioned[to][id])
                    revert NotPermitted();
            }

            balanceOf[from][id] -= amount;

            // Cannot overflow because the sum of all user
            // balances can't exceed the max uint256 value.
            unchecked {
                balanceOf[to][id] += amount;
            }

            _moveVotingPower(
                delegates(from, id),
                delegates(to, id),
                id,
                amount
            );

            // An array can't have a total length
            // larger than the max uint256 value.
            unchecked {
                ++i;
            }
        }

        emit TransferBatch(msg.sender, from, to, ids, amounts);

        if (to.code.length != 0) {
            if (
                ERC1155TokenReceiver(to).onERC1155BatchReceived(
                    msg.sender,
                    from,
                    ids,
                    amounts,
                    data
                ) != ERC1155TokenReceiver.onERC1155BatchReceived.selector
            ) {
                revert UnsafeRecipient();
            }
        } else if (to == address(0)) {
            revert InvalidRecipient();
        }
    }

    /// -----------------------------------------------------------------------
    /// EIP-2612-style Permit Logic
    /// -----------------------------------------------------------------------

    function permit(
        address owner,
        address operator,
        bool approved,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public payable virtual {
        if (block.timestamp > deadline) revert ExpiredSig();

        // Unchecked because the only math done is incrementing
        // the owner's nonce which cannot realistically overflow.
        unchecked {
            address recoveredAddress = ecrecover(
                keccak256(
                    abi.encodePacked(
                        "\x19\x01",
                        DOMAIN_SEPARATOR(),
                        keccak256(
                            abi.encode(
                                keccak256(
                                    "Permit(address owner,address operator,bool approved,uint256 nonce,uint256 deadline)"
                                ),
                                owner,
                                operator,
                                approved,
                                nonces[owner]++,
                                deadline
                            )
                        )
                    )
                ),
                v,
                r,
                s
            );

            if (recoveredAddress == address(0)) revert InvalidSig();

            if (recoveredAddress != owner) revert InvalidSig();

            isApprovedForAll[recoveredAddress][operator] = approved;
        }

        emit ApprovalForAll(owner, operator, approved);
    }

    /// -----------------------------------------------------------------------
    /// Checkpoint Storage/Logic
    /// -----------------------------------------------------------------------

    function numCheckpoints(address account, uint256 id)
        public
        view
        virtual
        returns (uint256)
    {
        return checkpoints[account][id].length;
    }

    function getVotes(address account, uint256 id)
        public
        view
        virtual
        returns (uint256)
    {
        return getCurrentVotes(account, id);
    }

    function getCurrentVotes(address account, uint256 id)
        public
        view
        virtual
        returns (uint256)
    {
        uint256 pos = checkpoints[account][id].length;

        // Unchecked because subtraction only occurs if positive `pos`.
        unchecked {
            return pos == 0 ? 0 : checkpoints[account][id][pos - 1].votes;
        }
    }

    function getPastVotes(
        address account,
        uint256 id,
        uint256 timestamp
    ) public view virtual returns (uint256) {
        return getPriorVotes(account, id, timestamp);
    }

    function getPriorVotes(
        address account,
        uint256 id,
        uint256 timestamp
    ) public view virtual returns (uint256) {
        if (block.timestamp <= timestamp) revert Undetermined();

        return _checkpointsLookup(checkpoints[account][id], timestamp);
    }

    function getPastTotalSupply(uint256 id, uint256 timestamp)
        public
        view
        virtual
        returns (uint256)
    {
        if (block.timestamp <= timestamp) revert Undetermined();

        return _checkpointsLookup(totalSupplyCheckpoints[id], timestamp);
    }

    function _checkpointsLookup(Checkpoint[] storage ckpts, uint256 timestamp)
        internal
        view
        virtual
        returns (uint256)
    {
        uint256 length = ckpts.length;
        uint256 low;
        uint256 high = length;

        // Unchecked because math is bounded.
        unchecked {
            if (length > 5) {
                uint256 mid = length - _sqrt(length);

                if (_unsafeAccess(ckpts, mid).fromTimestamp > timestamp) {
                    high = mid;
                } else {
                    low = mid + 1;
                }
            }

            while (low < high) {
                uint256 mid = ((low & high) + (low ^ high)) >> 1;

                if (_unsafeAccess(ckpts, mid).fromTimestamp > timestamp) {
                    high = mid;
                } else {
                    low = mid + 1;
                }
            }

            return high == 0 ? 0 : _unsafeAccess(ckpts, high - 1).votes;
        }
    }

    function _moveVotingPower(
        address src,
        address dst,
        uint256 id,
        uint256 amount
    ) internal virtual {
        if (src != dst && amount != 0) {
            if (src != address(0)) {
                (uint256 oldWeight, uint256 newWeight) = _writeCheckpoint(
                    checkpoints[src][id],
                    totalSupplyCheckpoints[id],
                    _subtract,
                    amount
                );
                emit DelegateVotesChanged(src, id, oldWeight, newWeight);
            }

            if (dst != address(0)) {
                (uint256 oldWeight, uint256 newWeight) = _writeCheckpoint(
                    checkpoints[dst][id],
                    totalSupplyCheckpoints[id],
                    _add,
                    amount
                );
                emit DelegateVotesChanged(dst, id, oldWeight, newWeight);
            }
        }
    }

    function _writeCheckpoint(
        Checkpoint[] storage ckpts,
        Checkpoint[] storage totalCkpts,
        function(uint256, uint256) view returns (uint256) op,
        uint256 delta
    ) internal virtual returns (uint256 oldWeight, uint256 newWeight) {
        uint256 pos = ckpts.length;
        uint256 totalPos = totalCkpts.length;

        unchecked {
            Checkpoint memory oldCkpt = pos == 0
                ? Checkpoint(0, 0)
                : _unsafeAccess(ckpts, pos - 1);

            oldWeight = oldCkpt.votes;
            newWeight = op(oldWeight, delta);

            if (pos != 0 && oldCkpt.fromTimestamp == block.timestamp) {
                _unsafeAccess(ckpts, pos - 1).votes = _safeCastTo216(newWeight);
                _unsafeAccess(totalCkpts, totalPos - 1).votes = _safeCastTo216(
                    newWeight
                );
            } else {
                ckpts.push(
                    Checkpoint({
                        fromTimestamp: _safeCastTo40(block.timestamp),
                        votes: _safeCastTo216(newWeight)
                    })
                );
                totalCkpts.push(
                    Checkpoint({
                        fromTimestamp: _safeCastTo40(block.timestamp),
                        votes: _safeCastTo216(newWeight)
                    })
                );
            }
        }
    }

    function _unsafeAccess(Checkpoint[] storage ckpts, uint256 pos)
        internal
        pure
        returns (Checkpoint storage result)
    {
        assembly {
            mstore(0, ckpts.slot)
            result.slot := add(keccak256(0, 0x20), pos)
        }
    }

    /// -----------------------------------------------------------------------
    /// Delegation Storage/Logic
    /// -----------------------------------------------------------------------

    function delegates(address account, uint256 id)
        public
        view
        virtual
        returns (address)
    {
        address current = _delegates[account][id];

        return current == address(0) ? account : current;
    }

    function delegate(address delegatee, uint256 id) public payable virtual {
        _delegate(msg.sender, delegatee, id);
    }

    function delegateBySig(
        address delegatee,
        uint256 id,
        uint256 nonce,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public payable virtual {
        if (block.timestamp > deadline) revert ExpiredSig();

        address recoveredAddress = ecrecover(
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            keccak256(
                                "Delegation(address delegatee,uint256 id,uint256 nonce,uint256 deadline)"
                            ),
                            delegatee,
                            id,
                            nonce,
                            deadline
                        )
                    )
                )
            ),
            v,
            r,
            s
        );

        if (recoveredAddress == address(0)) revert InvalidSig();

        // Cannot realistically overflow on human timescales.
        unchecked {
            if (nonce != nonces[recoveredAddress]++) revert InvalidSig();
        }

        _delegate(recoveredAddress, delegatee, id);
    }

    function _delegate(
        address delegator,
        address delegatee,
        uint256 id
    ) internal virtual {
        address currentDelegate = delegates(delegator, id);

        _delegates[delegator][id] = delegatee;

        emit DelegateChanged(delegator, currentDelegate, delegatee, id);

        _moveVotingPower(
            currentDelegate,
            delegatee,
            id,
            balanceOf[delegator][id]
        );
    }

    /// -----------------------------------------------------------------------
    /// Math Helpers
    /// -----------------------------------------------------------------------

    function _add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    function _subtract(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    function _sqrt(uint256 x) internal pure returns (uint256 z) {
        assembly {
            // `floor(sqrt(2**15)) = 181`. `sqrt(2**15) - 181 = 2.84`.
            z := 181 // The "correct" value is 1, but this saves a multiplication later.

            // This segment is to get a reasonable initial estimate for the Babylonian method. With a bad
            // start, the correct # of bits increases ~linearly each iteration instead of ~quadratically.

            // Let `y = x / 2**r`.
            // We check `y >= 2**(k + 8)` but shift right by `k` bits
            // each branch to ensure that if `x >= 256`, then `y >= 256`.
            let r := shl(7, gt(x, 0xffffffffffffffffffffffffffffffffff))
            r := or(r, shl(6, gt(shr(r, x), 0xffffffffffffffffff)))
            r := or(r, shl(5, gt(shr(r, x), 0xffffffffff)))
            r := or(r, shl(4, gt(shr(r, x), 0xffffff)))
            z := shl(shr(1, r), z)

            // Goal was to get `z*z*y` within a small factor of `x`. More iterations could
            // get y in a tighter range. Currently, we will have y in `[256, 256*(2**16))`.
            // We ensured `y >= 256` so that the relative difference between `y` and `y+1` is small.
            // That's not possible if `x < 256` but we can just verify those cases exhaustively.

            // Now, `z*z*y <= x < z*z*(y+1)`, and `y <= 2**(16+8)`, and either `y >= 256`, or `x < 256`.
            // Correctness can be checked exhaustively for `x < 256`, so we assume `y >= 256`.
            // Then `z*sqrt(y)` is within `sqrt(257)/sqrt(256)` of `sqrt(x)`, or about 20bps.

            // For `s` in the range `[1/256, 256]`, the estimate `f(s) = (181/1024) * (s+1)`
            // is in the range `(1/2.84 * sqrt(s), 2.84 * sqrt(s))`,
            // with largest error when `s = 1` and when `s = 256` or `1/256`.

            // Since `y` is in `[256, 256*(2**16))`, let `a = y/65536`, so that `a` is in `[1/256, 256)`.
            // Then we can estimate `sqrt(y)` using
            // `sqrt(65536) * 181/1024 * (a + 1) = 181/4 * (y + 65536)/65536 = 181 * (y + 65536)/2**18`.

            // There is no overflow risk here since `y < 2**136` after the first branch above.
            z := shr(18, mul(z, add(shr(r, x), 65536))) // A `mul()` is saved from starting `z` at 181.

            // Given the worst case multiplicative error of 2.84 above, 7 iterations should be enough.
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))

            // If `x+1` is a perfect square, the Babylonian method cycles between
            // `floor(sqrt(x))` and `ceil(sqrt(x))`. This statement ensures we return floor.
            // See: https://en.wikipedia.org/wiki/Integer_square_root#Using_only_integer_division
            // Since the ceil is rare, we save gas on the assignment and repeat division in the rare case.
            // If you don't care whether the floor or ceil square root is returned, you can remove this statement.
            z := sub(z, lt(div(x, z), z))
        }
    }

    /// -----------------------------------------------------------------------
    /// Safecast Logic
    /// -----------------------------------------------------------------------

    function _safeCastTo40(uint256 x) internal pure virtual returns (uint40) {
        if (x >= (1 << 40)) revert Overflow();

        return uint40(x);
    }

    function _safeCastTo216(uint256 x) internal pure virtual returns (uint216) {
        if (x >= (1 << 216)) revert Overflow();

        return uint216(x);
    }

    /// -----------------------------------------------------------------------
    /// Internal Mint/Burn Logic
    /// -----------------------------------------------------------------------

    function _mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) public virtual {
        _safeCastTo216(totalSupply[id] += amount);

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to][id] += amount;
        }

        emit TransferSingle(msg.sender, address(0), to, id, amount);

        if (to.code.length != 0) {
            if (
                ERC1155TokenReceiver(to).onERC1155Received(
                    msg.sender,
                    address(0),
                    id,
                    amount,
                    data
                ) != ERC1155TokenReceiver.onERC1155Received.selector
            ) {
                revert UnsafeRecipient();
            }
        } else if (to == address(0)) {
            revert InvalidRecipient();
        }

        _moveVotingPower(address(0), delegates(to, id), id, amount);
    }

    function _burn(
        address from,
        uint256 id,
        uint256 amount
    ) public virtual {
        balanceOf[from][id] -= amount;

        // Cannot underflow because a user's balance
        // will never be larger than the total supply.
        unchecked {
            totalSupply[id] -= amount;
        }

        emit TransferSingle(msg.sender, from, address(0), id, amount);

        _moveVotingPower(delegates(from, id), address(0), id, amount);
    }

    /// -----------------------------------------------------------------------
    /// Internal Permission Logic
    /// -----------------------------------------------------------------------

    function _setTransferability(uint256 id, bool set) internal virtual {
        transferable[id] = set;

        emit TransferabilitySet(msg.sender, id, set);
    }

    function _setPermission(uint256 id, bool set) internal virtual {
        permissioned[id] = set;

        emit PermissionSet(msg.sender, id, set);
    }

    function _setUserPermission(
        address to,
        uint256 id,
        bool set
    ) internal virtual {
        userPermissioned[to][id] = set;

        emit UserPermissionSet(msg.sender, to, id, set);
    }
}
