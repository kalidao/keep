// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {UserOperation} from "../../Keep.sol";
import {Owned} from "../utils/Owned.sol";

/// @notice Open-ended metadata for ERC1155 and ERC4337 permission fetching.
contract Fetcher is Owned(tx.origin) {
    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event PermissionRemoteFetcherSet(Fetcher indexed permissionRemoteFetcher);

    event URIRemoteFetcherSet(Fetcher indexed uriRemoteFetcher);

    event EntryPointSet(address indexed entryPoint);

    /// -----------------------------------------------------------------------
    /// Remote Storage
    /// -----------------------------------------------------------------------

    Fetcher public permissionRemoteFetcher;

    Fetcher public uriRemoteFetcher;

    address public entryPoint;

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor() payable {
        emit EntryPointSet(
            entryPoint = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789
        );
    }

    /// -----------------------------------------------------------------------
    /// Permission Remote Logic
    /// -----------------------------------------------------------------------

    function validatePermission(
        UserOperation calldata userOp,
        bytes32 hash
    ) public view virtual returns (uint256) {
        return permissionRemoteFetcher.validatePermission(userOp, hash);
    }

    function setPermissionRemoteFetcher(
        Fetcher _permissionRemoteFetcher
    ) public payable virtual onlyOwner {
        permissionRemoteFetcher = _permissionRemoteFetcher;

        emit PermissionRemoteFetcherSet(_permissionRemoteFetcher);
    }

    /// -----------------------------------------------------------------------
    /// URI Remote Logic
    /// -----------------------------------------------------------------------

    function uri(uint256 id) public view virtual returns (string memory) {
        return uriRemoteFetcher.uri(id);
    }

    function setURIRemoteFetcher(
        Fetcher _uriRemoteFetcher
    ) public payable virtual onlyOwner {
        uriRemoteFetcher = _uriRemoteFetcher;

        emit URIRemoteFetcherSet(_uriRemoteFetcher);
    }

    /// -----------------------------------------------------------------------
    /// Entry Point Logic
    /// -----------------------------------------------------------------------

    function setEntryPoint(
        address _entryPoint
    ) public payable virtual onlyOwner {
        entryPoint = _entryPoint;

        emit EntryPointSet(_entryPoint);
    }
}
