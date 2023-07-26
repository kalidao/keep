# Owned
[Git Source](https://github.com/kalidao/keep/blob/e52b433e668648f92907034179bd28358496fd0a/src/extensions/utils/Owned.sol)

**Author:**
Modified from Solbase (https://github.com/Sol-DAO/solbase/blob/main/src/auth/Owned.sol)

Simple single owner authorization mixin that implements ERC173.


## State Variables
### owner
-----------------------------------------------------------------------
Ownership Storage
-----------------------------------------------------------------------


```solidity
address public owner;
```


## Functions
### onlyOwner


```solidity
modifier onlyOwner() virtual;
```

### constructor

-----------------------------------------------------------------------
Constructor
-----------------------------------------------------------------------


```solidity
constructor(address _owner);
```

### transferOwnership

-----------------------------------------------------------------------
Ownership Logic
-----------------------------------------------------------------------


```solidity
function transferOwnership(address newOwner) public payable virtual onlyOwner;
```

### supportsInterface

-----------------------------------------------------------------------
ERC165 Logic
-----------------------------------------------------------------------


```solidity
function supportsInterface(bytes4 interfaceId) public view virtual returns (bool);
```

## Events
### OwnershipTransferred
-----------------------------------------------------------------------
Events
-----------------------------------------------------------------------


```solidity
event OwnershipTransferred(address indexed owner, address indexed newOwner);
```

## Errors
### Unauthorized
-----------------------------------------------------------------------
Custom Errors
-----------------------------------------------------------------------


```solidity
error Unauthorized();
```

