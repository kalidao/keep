// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Simple single owner authorization mixin that implements ERC173.
abstract contract Ownable {
    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event OwnershipTransferred(address indexed owner, address indexed _owner);

    /// -----------------------------------------------------------------------
    /// Custom Errors
    /// -----------------------------------------------------------------------

    error Unauthorized();

    /// -----------------------------------------------------------------------
    /// Ownership Storage
    /// -----------------------------------------------------------------------

    address public owner;

    modifier onlyOwner() virtual {
        if (msg.sender != owner) revert Unauthorized();

        _;
    }

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor(address _owner) {
        owner = _owner;

        emit OwnershipTransferred(address(0), _owner);
    }

    /// -----------------------------------------------------------------------
    /// Ownership Logic
    /// -----------------------------------------------------------------------

    function transferOwnership(
        address _owner
    ) public payable virtual onlyOwner {
        owner = _owner;

        emit OwnershipTransferred(msg.sender, _owner);
    }

    /// -----------------------------------------------------------------------
    /// ERC165 Logic
    /// -----------------------------------------------------------------------

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual returns (bool) {
        // ERC165 Interface ID for ERC173.
        return interfaceId == 0x7f5828d0;
    }
}
