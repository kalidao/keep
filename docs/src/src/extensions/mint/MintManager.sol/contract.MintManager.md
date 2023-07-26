# MintManager
[Git Source](https://github.com/kalidao/keep/blob/e52b433e668648f92907034179bd28358496fd0a/src/extensions/mint/MintManager.sol)

**Inherits:**
[Multicallable](/src/utils/Multicallable.sol/abstract.Multicallable.md)

**Author:**
z0r0z.eth

ERC1155 token ID mint permission manager.


## State Variables
### approved

```solidity
mapping(address => mapping(address => mapping(uint256 => bool))) public approved;
```


## Functions
### approve


```solidity
function approve(address manager, uint256 id, bool on) public payable virtual;
```

### mint


```solidity
function mint(address source, address to, uint256 id, uint256 amount, bytes calldata data) public payable virtual;
```

## Events
### Approved

```solidity
event Approved(address indexed source, address indexed manager, uint256 id, bool approve);
```

## Errors
### Unauthorized

```solidity
error Unauthorized();
```

