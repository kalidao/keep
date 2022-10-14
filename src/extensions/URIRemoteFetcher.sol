// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Owned} from "./utils/Owned.sol";

/// @notice Remote metadata fetcher for ERC1155.
contract URIRemoteFetcher is Owned {
    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event AlphaURISet(address indexed operator, string alphaURI);

    event BetaURISet(
        address indexed operator,
        address indexed origin,
        string betaURI
    );

    event URISet(
        address indexed operator,
        address indexed origin,
        uint256 indexed id,
        string uri
    );
    
    event UserURISet(
        address indexed operator,
        address indexed origin,
        address indexed user,
        string uri
    );
    
    event UserIdURISet(
        address indexed operator,
        address indexed origin,
        address indexed user,
        uint256 id,
        string uri
    );

    /// -----------------------------------------------------------------------
    /// URI Storage
    /// -----------------------------------------------------------------------

    string public alphaURI;

    mapping(address => string) public betaURI;

    mapping(address => mapping(uint256 => string)) public uris;
    
    mapping(address => mapping(address => string)) public userUris;
    
    mapping(address => mapping(address => mapping(uint256 => string))) public userIdUris;

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor(address _owner) payable Owned(_owner) {}

    /// -----------------------------------------------------------------------
    /// URI Logic
    /// -----------------------------------------------------------------------

    function fetchURI(address origin, uint256 id)
        public
        view
        virtual
        returns (string memory)
    {
        string memory alpha = alphaURI;
        string memory beta = betaURI[origin];
        string memory uri = uris[origin][id];

        if (bytes(uri).length != 0) return uri;
        else if (bytes(beta).length != 0) return beta;
        else return bytes(alpha).length != 0 ? alpha : "";
    }

    function setAlphaURI(string calldata _alphaURI)
        public
        payable
        virtual
        onlyOwner
    {
        alphaURI = _alphaURI;

        emit AlphaURISet(msg.sender, _alphaURI);
    }

    function setBetaURI(address origin, string calldata beta)
        public
        payable
        virtual
        onlyOwner
    {
        betaURI[origin] = beta;

        emit BetaURISet(msg.sender, origin, beta);
    }

    function setURI(
        address origin,
        uint256 id,
        string calldata uri
    ) public payable virtual onlyOwner {
        uris[origin][id] = uri;

        emit URISet(msg.sender, origin, id, uri);
    }
    
    function setUserURI(
        address origin,
        address user,
        string calldata uri
    ) public payable virtual onlyOwner {
        userUris[origin][user] = uri;

        emit UserURISet(msg.sender, origin, user, uri);
    }
    
    function setUserIdURI(
        address origin,
        address user,
        uint256 id,
        string calldata uri
    ) public payable virtual onlyOwner {
        userIdUris[origin][user][id] = uri;

        emit UserIdURISet(msg.sender, origin, user, id, uri);
    }
}
