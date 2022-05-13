// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {IClub} from './interfaces/IClub.sol';
import {Multicall} from './utils/Multicall.sol';

/// @notice Modern, minimalist, and gas efficient ERC-20 + EIP-2612 implementation designed for Kali ClubSig
/// @dev Includes delegation tracking based on Compound governance system, adapted with unix timestamps
/// @author Modified from Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/tokens/ERC20.sol)
/// License-Identifier: AGPL-3.0-only
contract ClubLoot is IClub, Multicall {
    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 amount
    );
    event DelegateChanged(
        address indexed delegator,
        address indexed fromDelegate,
        address indexed toDelegate
    );
    event DelegateVotesChanged(
        address indexed delegate,
        uint256 previousBalance,
        uint256 newBalance
    );
    event GovSet(address indexed governance, bool approved);
    event PauseSet(bool paused);

    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    error NotGov();
    error Paused();
    error AlreadyInitialized();
    error SignatureExpired();
    error InvalidSignature();
    error NotDetermined();
    error Uint64max();
    error Uint192max();

    /// -----------------------------------------------------------------------
    /// Metadata Storage/Logic
    /// -----------------------------------------------------------------------

    function name() public pure returns (string memory) {
        return
            string(
                abi.encodePacked(
                    string(abi.encodePacked(_getArgUint256(0))),
                    ' LOOT'
                )
            );
    }

    function symbol() external pure returns (string memory) {
        return
            string(
                abi.encodePacked(
                    string(abi.encodePacked(_getArgUint256(0x20))),
                    '-LOOT'
                )
            );
    }

    function _getArgUint256(uint256 argOffset)
        private
        pure
        returns (uint256 arg)
    {
        uint256 offset;

        assembly {
            offset := sub(
                calldatasize(),
                add(shr(240, calldataload(sub(calldatasize(), 2))), 2)
            )
        }
        assembly {
            arg := calldataload(add(offset, argOffset))
        }
    }

    uint8 public constant decimals = 18;

    /// -----------------------------------------------------------------------
    /// ERC-20 Storage
    /// -----------------------------------------------------------------------

    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    /// -----------------------------------------------------------------------
    /// EIP-2612 Storage
    /// -----------------------------------------------------------------------

    bytes32 private INITIAL_DOMAIN_SEPARATOR;

    mapping(address => uint256) public nonces;

    function INITIAL_CHAIN_ID() private pure returns (uint256 chainId) {
        uint256 offset;

        assembly {
            offset := sub(
                calldatasize(),
                add(shr(240, calldataload(sub(calldatasize(), 2))), 2)
            )
        }
        assembly {
            chainId := shr(0xc0, calldataload(add(offset, 0x40)))
        }
    }

    function DOMAIN_SEPARATOR() public view returns (bytes32) {
        return
            block.chainid == INITIAL_CHAIN_ID()
                ? INITIAL_DOMAIN_SEPARATOR
                : _computeDomainSeparator();
    }

    function _computeDomainSeparator() private view returns (bytes32) {
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
    /// DAO Storage
    /// -----------------------------------------------------------------------

    mapping(address => address) private _delegates;
    mapping(address => uint256) public numCheckpoints;
    mapping(address => mapping(uint256 => Checkpoint)) public checkpoints;

    struct Checkpoint {
        uint64 fromTimestamp;
        uint192 votes;
    }

    /// -----------------------------------------------------------------------
    /// Governor Storage
    /// -----------------------------------------------------------------------

    bool public paused;

    mapping(address => bool) public governors;

    modifier onlyGov() {
        if (!governors[msg.sender]) revert NotGov();
        _;
    }

    modifier notPaused() {
        if (paused) revert Paused();
        _;
    }

    /// -----------------------------------------------------------------------
    /// Initializer
    /// -----------------------------------------------------------------------

    function init(
        address governance_,
        Club[] calldata club_,
        bool lootPaused_
    ) external payable {
        if (INITIAL_DOMAIN_SEPARATOR != 0) revert AlreadyInitialized();

        uint256 totalSupply_;

        for (uint256 i; i < club_.length; ) {
            totalSupply_ += club_[i].loot;

            _moveDelegates(address(0), club_[i].signer, club_[i].loot);

            emit Transfer(address(0), club_[i].signer, club_[i].loot);
            // cannot overflow because the sum of all user
            // balances can't exceed the max uint256 value,
            // and incrementing cannot realistically overflow
            unchecked {
                balanceOf[club_[i].signer] += club_[i].loot;
                ++i;
            }
        }

        totalSupply = totalSupply_;
        paused = lootPaused_;
        governors[governance_] = true;
        INITIAL_DOMAIN_SEPARATOR = _computeDomainSeparator();
    }

    /// -----------------------------------------------------------------------
    /// ERC-20 Logic
    /// -----------------------------------------------------------------------

    function approve(address spender, uint256 amount)
        external
        payable
        returns (bool)
    {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount)
        external
        payable
        notPaused
        returns (bool)
    {
        balanceOf[msg.sender] -= amount;
        // cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value
        unchecked {
            balanceOf[to] += amount;
        }

        _moveDelegates(delegates(msg.sender), delegates(to), amount);

        emit Transfer(msg.sender, to, amount);

        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external payable notPaused returns (bool) {
        uint256 allowed = allowance[from][msg.sender]; // saves gas for limited approvals

        if (allowed != type(uint256).max)
            allowance[from][msg.sender] = allowed - amount;

        balanceOf[from] -= amount;
        // cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value
        unchecked {
            balanceOf[to] += amount;
        }

        _moveDelegates(delegates(from), delegates(to), amount);

        emit Transfer(from, to, amount);

        return true;
    }

    /// -----------------------------------------------------------------------
    /// EIP-2612 Logic
    /// -----------------------------------------------------------------------

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable {
        if (block.timestamp > deadline) revert SignatureExpired();
        // unchecked because the only math done is incrementing
        // the owner's nonce which cannot realistically overflow
        unchecked {
            address recoveredAddress = ecrecover(
                keccak256(
                    abi.encodePacked(
                        '\x19\x01',
                        DOMAIN_SEPARATOR(),
                        keccak256(
                            abi.encode(
                                keccak256(
                                    'Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)'
                                ),
                                owner,
                                spender,
                                value,
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

            if (recoveredAddress == address(0) || recoveredAddress != owner)
                revert InvalidSignature();

            allowance[recoveredAddress][spender] = value;
        }

        emit Approval(owner, spender, value);
    }

    /// -----------------------------------------------------------------------
    /// Burn Logic
    /// -----------------------------------------------------------------------

    function _burn(address from, uint256 amount) private {
        balanceOf[from] -= amount;
        // cannot underflow because a user's balance
        // will never be larger than the total supply
        unchecked {
            totalSupply -= amount;
        }

        _moveDelegates(delegates(from), address(0), amount);

        emit Transfer(from, address(0), amount);
    }

    function burn(uint256 amount) external payable {
        _burn(msg.sender, amount);
    }

    function burnFrom(address from, uint256 amount) external payable {
        uint256 allowed = allowance[from][msg.sender]; // saves gas for limited approvals

        if (allowed != type(uint256).max)
            allowance[from][msg.sender] = allowed - amount;

        _burn(from, amount);
    }

    /// -----------------------------------------------------------------------
    /// DAO Logic
    /// -----------------------------------------------------------------------

    function delegates(address delegator) public view returns (address) {
        address current = _delegates[delegator];
        return current == address(0) ? delegator : current;
    }

    function getCurrentVotes(address account) external view returns (uint256) {
        // this is safe from underflow because decrement only occurs if `nCheckpoints` is positive
        unchecked {
            uint256 nCheckpoints = numCheckpoints[account];
            return
                nCheckpoints != 0
                    ? checkpoints[account][nCheckpoints-1].votes
                    : 0;
        }
    }

    function getPriorVotes(address account, uint256 timestamp)
        external
        view
        returns (uint256)
    {
        if (block.timestamp <= timestamp) revert NotDetermined();

        uint256 nCheckpoints = numCheckpoints[account];

        if (nCheckpoints == 0) return 0;

        // this is safe from underflow because decrement only occurs if `nCheckpoints` is positive
        unchecked {
            if (
                checkpoints[account][nCheckpoints-1].fromTimestamp <=
                timestamp
            ) return checkpoints[account][nCheckpoints-1].votes;
            if (checkpoints[account][0].fromTimestamp > timestamp) return 0;

            uint256 lower;
            // this is safe from underflow because decrement only occurs if `nCheckpoints` is positive
            uint256 upper = --nCheckpoints;

            while (upper > lower) {
                // this is safe from underflow because `upper` ceiling is provided
                uint256 center = upper - (upper - lower) / 2;

                Checkpoint memory cp = checkpoints[account][center];

                if (cp.fromTimestamp == timestamp) {
                    return cp.votes;
                } else if (cp.fromTimestamp < timestamp) {
                    lower = center;
                } else {
                    upper = --center;
                }
            }

            return checkpoints[account][lower].votes;
        }
    }

    function delegate(address delegatee) external payable {
        address currentDelegate = delegates(msg.sender);

        _delegates[msg.sender] = delegatee;
        _moveDelegates(currentDelegate, delegatee, balanceOf[msg.sender]);

        emit DelegateChanged(msg.sender, currentDelegate, delegatee);
    }

    function _moveDelegates(
        address srcRep,
        address dstRep,
        uint256 amount
    ) private {
        if (srcRep != dstRep && amount != 0)
            if (srcRep != address(0)) {
                uint256 srcRepNum = numCheckpoints[srcRep];
                uint256 srcRepOld = srcRepNum != 0
                    ? checkpoints[srcRep][srcRepNum-1].votes
                    : 0;
                uint256 srcRepNew = srcRepOld - amount;

                _writeCheckpoint(srcRep, srcRepNum, srcRepOld, srcRepNew);
            }

        if (dstRep != address(0)) {
            uint256 dstRepNum = numCheckpoints[dstRep];
            uint256 dstRepOld = dstRepNum != 0
                ? checkpoints[dstRep][dstRepNum-1].votes
                : 0;
            uint256 dstRepNew = dstRepOld + amount;

            _writeCheckpoint(dstRep, dstRepNum, dstRepOld, dstRepNew);
        }
    }

    function _writeCheckpoint(
        address delegatee,
        uint256 nCheckpoints,
        uint256 oldVotes,
        uint256 newVotes
    ) private {
        unchecked {
            // this is safe from underflow because decrement only occurs if `nCheckpoints` is positive
            if (
                nCheckpoints != 0 &&
                checkpoints[delegatee][nCheckpoints-1].fromTimestamp ==
                block.timestamp
            ) {
                checkpoints[delegatee][nCheckpoints-1].votes = _safeCastTo192(
                    newVotes
                );
            } else {
                checkpoints[delegatee][nCheckpoints] = Checkpoint(
                    _safeCastTo64(block.timestamp),
                    _safeCastTo192(newVotes)
                );
                // cannot realistically overflow
                numCheckpoints[delegatee] = nCheckpoints + 1;
            }
        }

        emit DelegateVotesChanged(delegatee, oldVotes, newVotes);
    }

    function _safeCastTo64(uint256 x) private pure returns (uint64 y) {
        if (x > 1 << 64) revert Uint64max();
        y = uint64(x);
    }

    function _safeCastTo192(uint256 x) private pure returns (uint192 y) {
        if (x > 1 << 192) revert Uint192max();
        y = uint192(x);
    }

    /// -----------------------------------------------------------------------
    /// Governance Logic
    /// -----------------------------------------------------------------------

    function mintShares(address to, uint256 amount) external payable onlyGov {
        totalSupply += amount;
        // cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value
        unchecked {
            balanceOf[to] += amount;
        }

        _moveDelegates(address(0), delegates(to), amount);

        emit Transfer(address(0), to, amount);
    }

    function burnShares(address from, uint256 amount) external payable onlyGov {
        _burn(from, amount);
    }
    
    function setGov(address governance_, bool approved_)
        external
        payable
        onlyGov
    {
        governors[governance_] = approved_;
        emit GovSet(governance_, approved_);
    }

    function setPause(bool paused_) external payable onlyGov {
        paused = paused_;
        emit PauseSet(paused_);
    }
}
