# URIFetcher
[Git Source](https://github.com/kalidao/keep/blob/bf21b4d1d146ef800f17003b87f2cf6914c6539e/src/extensions/metadata/URIFetcher.sol)

**Inherits:**
Owned

**Author:**
z0r0z.eth

Open-ended metadata fetcher for ERC1155.


## State Variables
### uriRemoteFetcher
-----------------------------------------------------------------------
URI Remote Storage
-----------------------------------------------------------------------


```solidity
URIRemoteFetcher public uriRemoteFetcher;
```


## Functions
### constructor

-----------------------------------------------------------------------
Constructor
-----------------------------------------------------------------------


```solidity
constructor(address _owner, URIRemoteFetcher _uriRemoteFetcher) payable Owned(_owner);
```

### uri

-----------------------------------------------------------------------
URI Remote Logic
-----------------------------------------------------------------------


```solidity
function uri(uint256 id) public view virtual returns (string memory);
```

### setURIRemoteFetcher


```solidity
function setURIRemoteFetcher(URIRemoteFetcher _uriRemoteFetcher) public payable virtual onlyOwner;
```

## Events
### URIRemoteFetcherSet
-----------------------------------------------------------------------
Events
-----------------------------------------------------------------------


```solidity
event URIRemoteFetcherSet(URIRemoteFetcher indexed uriRemoteFetcher);
```

