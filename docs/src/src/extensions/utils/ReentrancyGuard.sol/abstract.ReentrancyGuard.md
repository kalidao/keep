# ReentrancyGuard
[Git Source](https://github.com/kalidao/keep/blob/e52b433e668648f92907034179bd28358496fd0a/src/extensions/utils/ReentrancyGuard.sol)

**Author:**
Modified from Solbase (https://github.com/Sol-DAO/solbase/blob/main/src/utils/ReentrancyGuard.sol)

Reentrancy protection for contracts.


## State Variables
### locked

```solidity
uint256 internal locked = 1;
```


## Functions
### nonReentrant


```solidity
modifier nonReentrant() virtual;
```

## Errors
### Reentrancy

```solidity
error Reentrancy();
```

