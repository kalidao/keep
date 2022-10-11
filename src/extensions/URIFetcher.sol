// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Interface for remote metadata fetcher for ERC1155 URI.
abstract contract URIRemoteFetcher {
    function fetchURI(address origin, uint256 id) public view virtual returns (string memory);
}

/// @notice Open-ended metadata fetcher for ERC1155 URI.
/// @author z0r0z.eth
contract URIFetcher {
    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event OwnerUpdated(address indexed owner, address indexed newOwner);

    event URIRemoteFetcherSet(
        address indexed owner, 
        URIRemoteFetcher indexed uriRemoteFetcher
    );

    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    error NotOwner();

    /// -----------------------------------------------------------------------
    /// Ownership Storage
    /// -----------------------------------------------------------------------

    address public owner;

    /// -----------------------------------------------------------------------
    /// URI Storage
    /// -----------------------------------------------------------------------

    URIRemoteFetcher public uriRemoteFetcher;

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor(address _owner) payable {
        owner = _owner;

        emit OwnerUpdated(address(0), _owner);
    }

    /// -----------------------------------------------------------------------
    /// Ownership Logic
    /// -----------------------------------------------------------------------

    function setOwner(address _owner) public payable virtual {
        if (msg.sender != owner) revert NotOwner();

        owner = _owner;

        emit OwnerUpdated(msg.sender, _owner);
    }

    /// -----------------------------------------------------------------------
    /// URI Logic
    /// -----------------------------------------------------------------------

    function uri(uint256 id) public view virtual returns (string memory) {
        return uriRemoteFetcher.fetchURI(msg.sender, id);
    }

    function setURIRemote(URIRemoteFetcher _uriRemoteFetcher) public payable virtual {
        if (msg.sender != owner) revert NotOwner();

        uriRemoteFetcher = _uriRemoteFetcher;

        emit URIRemoteFetcherSet(msg.sender, _uriRemoteFetcher);
    }
}