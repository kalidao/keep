# ReentrancyGuard
[Git Source](https://github.com/kalidao/keep/blob/4ba354e122c2e294d53e3539ad035bb2950c6c96/src/extensions/utils/ReentrancyGuard.sol)

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

