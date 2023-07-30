# URIRemoteFetcher
[Git Source](https://github.com/kalidao/keep/blob/4ba354e122c2e294d53e3539ad035bb2950c6c96/src/extensions/metadata/URIRemoteFetcher.sol)

**Inherits:**
[Owned](/src/extensions/utils/Owned.sol/abstract.Owned.md)

Remote metadata fetcher for ERC1155.


## State Variables
### alphaURI
-----------------------------------------------------------------------
URI Storage
-----------------------------------------------------------------------


```solidity
string public alphaURI;
```


### betaURI

```solidity
mapping(address => string) public betaURI;
```


### uris

```solidity
mapping(address => mapping(uint256 => string)) public uris;
```


### userUris

```solidity
mapping(address => mapping(address => string)) public userUris;
```


### userIdUris

```solidity
mapping(address => mapping(address => mapping(uint256 => string))) public userIdUris;
```


## Functions
### constructor

-----------------------------------------------------------------------
Constructor
-----------------------------------------------------------------------


```solidity
constructor() payable;
```

### fetchURI

-----------------------------------------------------------------------
URI Logic
-----------------------------------------------------------------------


```solidity
function fetchURI(address origin, uint256 id) public view virtual returns (string memory);
```

### setAlphaURI


```solidity
function setAlphaURI(string calldata _alphaURI) public payable virtual onlyOwner;
```

### setBetaURI


```solidity
function setBetaURI(address origin, string calldata beta) public payable virtual onlyOwner;
```

### setURI


```solidity
function setURI(address origin, uint256 id, string calldata uri) public payable virtual onlyOwner;
```

### setUserURI


```solidity
function setUserURI(address origin, address user, string calldata uri) public payable virtual onlyOwner;
```

### setUserIdURI


```solidity
function setUserIdURI(address origin, address user, uint256 id, string calldata uri) public payable virtual onlyOwner;
```

## Events
### AlphaURISet
-----------------------------------------------------------------------
Events
-----------------------------------------------------------------------


```solidity
event AlphaURISet(string alphaURI);
```

### BetaURISet

```solidity
event BetaURISet(address indexed origin, string betaURI);
```

### URISet

```solidity
event URISet(address indexed origin, uint256 indexed id, string uri);
```

### UserURISet

```solidity
event UserURISet(address indexed origin, address indexed user, string uri);
```

### UserIdURISet

```solidity
event UserIdURISet(address indexed origin, address indexed user, uint256 indexed id, string uri);
```

