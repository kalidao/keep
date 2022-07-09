// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

/// @notice A generic interface for a contract which properly accepts ERC-1155 tokens
/// @author Modified from Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/tokens/ERC1155.sol)
abstract contract ERC1155TokenReceiver {
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external payable returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external payable returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }
}

/// @notice Minimalist and gas efficient standard ERC-1155 implementation with Compound-like voting
/// @author Modified from Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/tokens/ERC1155.sol)
/// and Compound Finance (https://github.com/compound-finance/compound-protocol/blob/master/contracts/Governance/Comp.sol)
abstract contract ERC1155Votes {
    /// -----------------------------------------------------------------------
    /// EVENTS
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

    event TokenTransferabilitySet(
        address indexed operator, 
        uint256 indexed id, 
        bool transferability
    );

    event URI(string value, uint256 indexed id);

    /// -----------------------------------------------------------------------
    /// ERRORS
    /// -----------------------------------------------------------------------

    error NOT_AUTHORIZED();

    error NONTRANSFERABLE();

    error INVALID_RECIPIENT();

    error LENGTH_MISMATCH();

    error UNDETERMINED();

    error UINT64_MAX();

    error UINT192_MAX();

    /// -----------------------------------------------------------------------
    /// ERC-1155 STORAGE
    /// -----------------------------------------------------------------------

    mapping(address => mapping(uint256 => uint256)) public balanceOf;

    mapping(address => mapping(address => bool)) public isApprovedForAll;

    /// -----------------------------------------------------------------------
    /// VOTING STORAGE
    /// -----------------------------------------------------------------------
    
    mapping(uint256 => bool) public transferable;

    mapping(uint256 => uint256) public totalSupply;
    
    mapping(address => mapping(uint256 => address)) internal _delegates;

    mapping(address => mapping(uint256 => uint256)) public numCheckpoints;

    mapping(address => mapping(uint256 => mapping(uint256 => Checkpoint))) public checkpoints;
    
    struct Checkpoint {
        uint64 fromTimestamp;
        uint192 votes;
    }

    /// -----------------------------------------------------------------------
    /// ERC-165 LOGIC
    /// -----------------------------------------------------------------------

    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return
            interfaceId == this.supportsInterface.selector || // ERC-165 Interface ID for ERC-165
            interfaceId == 0xd9b67a26 || // ERC-165 Interface ID for ERC-1155
            interfaceId == 0x0e89341c; // ERC-165 Interface ID for ERC1155MetadataURI
    }

    /// -----------------------------------------------------------------------
    /// ERC-1155 LOGIC
    /// -----------------------------------------------------------------------

    function balanceOfBatch(address[] calldata owners, uint256[] calldata ids)
        external
        view
        returns (uint256[] memory balances)
    {
        if (owners.length != ids.length) revert LENGTH_MISMATCH();

        balances = new uint256[](owners.length);

        for (uint256 i; i < owners.length; ) {
            balances[i] = balanceOf[owners[i]][ids[i]];

            // unchecked because the only math done is incrementing
            // the array index counter which cannot possibly overflow
            unchecked {
                ++i;
            }
        }
    }

    function setApprovalForAll(address operator, bool approved) external payable {
        isApprovedForAll[msg.sender][operator] = approved;

        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) external payable {
        if (msg.sender != from && !isApprovedForAll[from][msg.sender]) revert NOT_AUTHORIZED();

        if (!transferable[id]) revert NONTRANSFERABLE();

        balanceOf[from][id] -= amount;
        
        // cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value
        unchecked {
            balanceOf[to][id] += amount;
        }

        emit TransferSingle(msg.sender, from, to, id, amount);

        if (to.code.length == 0 ? to == address(0) :
            ERC1155TokenReceiver(to).onERC1155Received(msg.sender, from, id, amount, data) !=
                ERC1155TokenReceiver.onERC1155Received.selector
        ) revert INVALID_RECIPIENT();

        _moveDelegates(delegates(from, id), delegates(to, id), id, amount);
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external payable {
        if (ids.length != amounts.length) revert LENGTH_MISMATCH();

        if (msg.sender != from && !isApprovedForAll[from][msg.sender]) revert NOT_AUTHORIZED();

        // storing these outside the loop saves ~15 gas per iteration
        uint256 id;
        uint256 amount;

        for (uint256 i; i < ids.length; ) {
            id = ids[i];
            amount = amounts[i];

            if (!transferable[id]) revert NONTRANSFERABLE();

            balanceOf[from][id] -= amount;
            
            // cannot overflow because the sum of all user
            // balances can't exceed the max uint256 value
            unchecked {
                balanceOf[to][id] += amount;
            }

            _moveDelegates(delegates(from, id), delegates(to, id), id, amount);

            // an array can't have a total length
            // larger than the max uint256 value
            unchecked {
                ++i;
            }
        }

        emit TransferBatch(msg.sender, from, to, ids, amounts);

        if (to.code.length == 0 ? to == address(0) :
            ERC1155TokenReceiver(to).onERC1155BatchReceived(msg.sender, from, ids, amounts, data) !=
                ERC1155TokenReceiver.onERC1155BatchReceived.selector
        ) revert INVALID_RECIPIENT();
    }

    /// -----------------------------------------------------------------------
    /// VOTING LOGIC
    /// -----------------------------------------------------------------------

    function delegates(address account, uint256 id) public view returns (address) {
        address current = _delegates[account][id];

        return current == address(0) ? account : current;
    }

    function getCurrentVotes(address account, uint256 id) external view returns (uint256) {
        // won't underflow because decrement only occurs if positive `nCheckpoints`
        unchecked {
            uint256 nCheckpoints = numCheckpoints[account][id];

            return
                nCheckpoints != 0
                    ? checkpoints[account][id][nCheckpoints - 1].votes
                    : 0;
        }
    }

    function getPriorVotes(
        address account, 
        uint256 id,
        uint256 timestamp
    )
        external
        view
        returns (uint256)
    {
        if (block.timestamp <= timestamp) revert UNDETERMINED();

        uint256 nCheckpoints = numCheckpoints[account][id];

        if (nCheckpoints == 0) return 0;

        // won't underflow because decrement only occurs if positive `nCheckpoints`
        unchecked {
            if (
                checkpoints[account][id][nCheckpoints - 1].fromTimestamp <=
                timestamp
            ) return checkpoints[account][id][nCheckpoints - 1].votes;

            if (checkpoints[account][id][0].fromTimestamp > timestamp) return 0;

            uint256 lower;

            uint256 upper = nCheckpoints - 1;

            while (upper > lower) {
                uint256 center = upper - (upper - lower) / 2;

                Checkpoint memory cp = checkpoints[account][id][center];

                if (cp.fromTimestamp == timestamp) {
                    return cp.votes;
                } else if (cp.fromTimestamp < timestamp) {
                    lower = center;
                } else {
                    upper = center - 1;
                }
            }

            return checkpoints[account][id][lower].votes;
        }
    }

    function delegate(address delegatee, uint256 id) external payable {
        address currentDelegate = delegates(msg.sender, id);

        _delegates[msg.sender][id] = delegatee;

        emit DelegateChanged(msg.sender, currentDelegate, delegatee, id);

        _moveDelegates(currentDelegate, delegatee, id, balanceOf[msg.sender][id]);
    }

    function _moveDelegates(
        address srcRep,
        address dstRep,
        uint256 id,
        uint256 amount
    ) internal {
        if (srcRep != dstRep && amount != 0) {
            if (srcRep != address(0)) {
                uint256 srcRepNum = numCheckpoints[srcRep][id];

                uint256 srcRepOld = srcRepNum != 0
                    ? checkpoints[srcRep][id][srcRepNum - 1].votes
                    : 0;

                _writeCheckpoint(srcRep, id, srcRepNum, srcRepOld, srcRepOld - amount);
            }

            if (dstRep != address(0)) {
                uint256 dstRepNum = numCheckpoints[dstRep][id];

                uint256 dstRepOld = dstRepNum != 0
                    ? checkpoints[dstRep][id][dstRepNum - 1].votes
                    : 0;

                _writeCheckpoint(dstRep, id, dstRepNum, dstRepOld, dstRepOld + amount);
            }
        }
    }

    function _writeCheckpoint(
        address delegatee,
        uint256 id,
        uint256 nCheckpoints,
        uint256 oldVotes,
        uint256 newVotes
    ) internal {
        unchecked {
            uint64 timestamp = _safeCastTo64(block.timestamp);

            // won't underflow because decrement only occurs if positive `nCheckpoints`
            if (
                nCheckpoints != 0 &&
                checkpoints[delegatee][id][nCheckpoints - 1].fromTimestamp ==
                timestamp
            ) {
                checkpoints[delegatee][id][nCheckpoints - 1].votes = _safeCastTo192(
                    newVotes
                );
            } else {
                checkpoints[delegatee][id][nCheckpoints] = Checkpoint(
                    timestamp,
                    _safeCastTo192(newVotes)
                );

                // won't realistically overflow
                numCheckpoints[delegatee][id] = nCheckpoints + 1;
            }
        }

        emit DelegateVotesChanged(delegatee, id, oldVotes, newVotes);
    }
    
    function _safeCastTo64(uint256 x) internal pure returns (uint64 y) {
        if (x > 1 << 64) revert UINT64_MAX();

        y = uint64(x);
    }

    function _safeCastTo192(uint256 x) internal pure returns (uint192 y) {
        if (x > 1 << 192) revert UINT192_MAX();

        y = uint192(x);
    }

    /// -----------------------------------------------------------------------
    /// INTERNAL MINT/BURN LOGIC
    /// -----------------------------------------------------------------------

    function _mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) internal {
        totalSupply[id] += amount;
        
        // cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value 
        unchecked {
            balanceOf[to][id] += amount;
        }

        emit TransferSingle(msg.sender, address(0), to, id, amount);

        if (to.code.length == 0 ? to == address(0) :
            ERC1155TokenReceiver(to).onERC1155Received(msg.sender, address(0), id, amount, data) !=
               ERC1155TokenReceiver.onERC1155Received.selector
        ) revert INVALID_RECIPIENT();

        _moveDelegates(address(0), delegates(to, id), id, amount);
    }
    
    function _burn(
        address from,
        uint256 id,
        uint256 amount
    ) internal {
        balanceOf[from][id] -= amount;
        
        // cannot underflow because a user's balance
        // will never be larger than the total supply
        unchecked {
            totalSupply[id] -= amount;
        }

        emit TransferSingle(msg.sender, from, address(0), id, amount);

        _moveDelegates(delegates(from, id), address(0), id, amount);
    } 
}
