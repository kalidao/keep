# KeepFactory
[Git Source](https://github.com/kalidao/keep/blob/4ba354e122c2e294d53e3539ad035bb2950c6c96/src/KeepFactory.sol)

**Inherits:**
[Multicallable](/src/utils/Multicallable.sol/abstract.Multicallable.md)

Keep Factory.


## State Variables
### keepTemplate
-----------------------------------------------------------------------
Immutables
-----------------------------------------------------------------------


```solidity
address internal immutable keepTemplate;
```


## Functions
### constructor

-----------------------------------------------------------------------
Constructor
-----------------------------------------------------------------------


```solidity
constructor(address _keepTemplate) payable;
```

### determineKeep

-----------------------------------------------------------------------
Deployment Logic
-----------------------------------------------------------------------


```solidity
function determineKeep(bytes32 name) public view virtual returns (address);
```

### deployKeep


```solidity
function deployKeep(bytes32 name, Call[] calldata calls, address[] calldata signers, uint256 threshold)
    public
    payable
    virtual;
```

## Events
### Deployed
-----------------------------------------------------------------------
Library Usage
-----------------------------------------------------------------------
-----------------------------------------------------------------------
Events
-----------------------------------------------------------------------


```solidity
event Deployed(address indexed keep, address[] signers, uint256 threshold);
```

