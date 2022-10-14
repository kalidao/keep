// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Owned} from "@solbase/src/auth/Owned.sol";
import {URIRemoteFetcher} from "./URIRemoteFetcher.sol";

/// @notice Open-ended metadata fetcher for ERC1155.
/// @author z0r0z.eth
contract URIFetcher is Owned {
    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event URIRemoteFetcherSet(URIRemoteFetcher indexed uriRemoteFetcher);

    /// -----------------------------------------------------------------------
    /// URI Remote Storage
    /// -----------------------------------------------------------------------

    URIRemoteFetcher public uriRemoteFetcher;

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor(address _owner, URIRemoteFetcher _uriRemoteFetcher)
        payable
        Owned(_owner)
    {
        uriRemoteFetcher = _uriRemoteFetcher;
    }

    /// -----------------------------------------------------------------------
    /// URI Remote Logic
    /// -----------------------------------------------------------------------

    function uri(uint256 id) public view virtual returns (string memory) {
        return uriRemoteFetcher.fetchURI(msg.sender, id);
    }

    function setURIRemoteFetcher(URIRemoteFetcher _uriRemoteFetcher)
        public
        payable
        virtual
        onlyOwner
    {
        uriRemoteFetcher = _uriRemoteFetcher;

        emit URIRemoteFetcherSet(_uriRemoteFetcher);
    }
}
