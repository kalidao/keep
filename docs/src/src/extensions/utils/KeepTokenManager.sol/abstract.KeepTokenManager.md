# KeepTokenManager
[Git Source](https://github.com/kalidao/keep/blob/4ba354e122c2e294d53e3539ad035bb2950c6c96/src/extensions/utils/KeepTokenManager.sol)

Contract helper for Keep token management.


## Functions
### balanceOf


```solidity
function balanceOf(address account, uint256 id) public view virtual returns (uint256);
```

### totalSupply


```solidity
function totalSupply(uint256 id) public view virtual returns (uint256);
```

### transferable


```solidity
function transferable(uint256 id) public view virtual returns (bool);
```

### getPriorVotes


```solidity
function getPriorVotes(address account, uint256 id, uint256 timestamp) public view virtual returns (uint256);
```

### mint


```solidity
function mint(address to, uint256 id, uint256 amount, bytes calldata data) public payable virtual;
```

### burn


```solidity
function burn(address from, uint256 id, uint256 amount) public payable virtual;
```

### setTransferability


```solidity
function setTransferability(uint256 id, bool on) public payable virtual;
```

