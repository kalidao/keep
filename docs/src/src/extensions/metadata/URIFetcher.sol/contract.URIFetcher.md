# URIFetcher
[Git Source](https://github.com/kalidao/keep/blob/4ba354e122c2e294d53e3539ad035bb2950c6c96/src/extensions/metadata/URIFetcher.sol)

**Inherits:**
[Owned](/src/extensions/utils/Owned.sol/abstract.Owned.md)

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
constructor() payable;
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

