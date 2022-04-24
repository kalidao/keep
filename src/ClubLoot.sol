// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {IClub} from "./interfaces/IClub.sol";

/// @notice Modern, minimalist, and gas efficient ERC-20 + EIP-2612 implementation designed for Kali ClubSig
/// @author Modified from Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/tokens/ERC20.sol)
/// License-Identifier: AGPL-3.0-only
contract ClubLoot is IClub {
    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 amount
    );
    event PauseSet(bool paused);
    event GovSet(address indexed governance);

    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    error NotGov();
    error Paused();
    error AlreadyInitialized();
    error SignatureExpired();
    error InvalidSignature();

    /// -----------------------------------------------------------------------
    /// Metadata Storage/Logic
    /// -----------------------------------------------------------------------

    function name() public pure returns (string memory) {
        return
            string(
                abi.encodePacked(
                    string(abi.encodePacked(_getArgUint256(0))),
                    " LOOT"
                )
            );
    }

    function symbol() external pure returns (string memory) {
        return
            string(
                abi.encodePacked(
                    string(abi.encodePacked(_getArgUint256(0x20))),
                    "-LOOT"
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

    uint256 private INITIAL_CHAIN_ID;
    bytes32 private INITIAL_DOMAIN_SEPARATOR;

    mapping(address => uint256) public nonces;

    function DOMAIN_SEPARATOR() public view returns (bytes32) {
        return
            block.chainid == INITIAL_CHAIN_ID
                ? INITIAL_DOMAIN_SEPARATOR
                : _computeDomainSeparator();
    }

    function _computeDomainSeparator() private view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    keccak256(
                        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                    ),
                    keccak256(bytes(name())),
                    keccak256("1"),
                    block.chainid,
                    address(this)
                )
            );
    }

    /// -----------------------------------------------------------------------
    /// Governance Storage
    /// -----------------------------------------------------------------------

    address public governance;
    bool public paused;

    modifier onlyGov() {
        if (msg.sender != governance) revert NotGov();
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
        if (INITIAL_CHAIN_ID != 0) revert AlreadyInitialized();

        uint256 totalSupply_;

        for (uint256 i; i < club_.length; ) {
            totalSupply_ += club_[i].loot;

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
        governance = governance_;
        paused = lootPaused_;
        INITIAL_CHAIN_ID = block.chainid;
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
                        "\x19\x01",
                        DOMAIN_SEPARATOR(),
                        keccak256(
                            abi.encode(
                                keccak256(
                                    "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
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
    /// Governance Logic
    /// -----------------------------------------------------------------------

    function mint(address to, uint256 amount) external payable onlyGov {
        totalSupply += amount;
        // cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(address(0), to, amount);
    }

    function govBurn(address from, uint256 amount) external payable onlyGov {
        _burn(from, amount);
    }

    function setPause(bool paused_) external payable onlyGov {
        paused = paused_;
        emit PauseSet(paused_);
    }

    function setGov(address governance_) external payable onlyGov {
        governance = governance_;
        emit GovSet(governance_);
    }
}
