# IKeepFactory
[Git Source](https://github.com/kalidao/keep/blob/4ba354e122c2e294d53e3539ad035bb2950c6c96/src/utils/interfaces/IKeepFactory.sol)


## Functions
### deployKeep


```solidity
function deployKeep(bytes32 name, Call[] memory calls, address[] memory signers, uint256 threshold) external payable;
```

### determineKeep


```solidity
function determineKeep(bytes32 name) external view returns (address);
```

### multicall


```solidity
function multicall(bytes[] memory data) external payable returns (bytes[] memory);
```

## Events
### Deployed

```solidity
event Deployed(address indexed keep, address[] signers, uint256 threshold);
```

## Structs
### Call

```solidity
struct Call {
    uint8 op;
    address to;
    uint256 value;
    bytes data;
}
```

