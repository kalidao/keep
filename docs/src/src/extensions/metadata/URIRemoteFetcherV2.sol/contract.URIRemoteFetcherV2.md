# URIRemoteFetcherV2
[Git Source](https://github.com/kalidao/keep/blob/4ba354e122c2e294d53e3539ad035bb2950c6c96/src/extensions/metadata/URIRemoteFetcherV2.sol)

**Inherits:**
[Owned](/src/extensions/utils/Owned.sol/abstract.Owned.md)

Remote metadata fetcher for ERC1155.


## State Variables
### chainId

```solidity
uint256 internal immutable chainId;
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

### toString

*Returns the base 10 decimal representation of `value`.*


```solidity
function toString(uint256 value) internal pure returns (string memory str);
```

### toHexStringChecksummed

*Returns the hexadecimal representation of `value`.
The output is prefixed with "0x", encoded using 2 hexadecimal digits per byte,
and the alphabets are capitalized conditionally according to
https://eips.ethereum.org/EIPS/eip-55*


```solidity
function toHexStringChecksummed(address value) internal pure returns (string memory str);
```

### toHexString

*Returns the hexadecimal representation of `value`.
The output is prefixed with "0x" and encoded using 2 hexadecimal digits per byte.*


```solidity
function toHexString(address value) internal pure returns (string memory str);
```

### toHexStringNoPrefix

*Returns the hexadecimal representation of `value`.
The output is encoded using 2 hexadecimal digits per byte.*


```solidity
function toHexStringNoPrefix(address value) internal pure returns (string memory str);
```

