# URIFetcher
[Git Source](https://github.com/kalidao/keep/blob/1979341a5a2118c8b67dae50ac448106c85bacac/src/extensions/metadata/URIFetcher.sol)

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

