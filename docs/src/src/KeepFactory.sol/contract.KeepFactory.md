# KeepFactory
[Git Source](https://github.com/kalidao/keep/blob/bf21b4d1d146ef800f17003b87f2cf6914c6539e/src/KeepFactory.sol)

**Inherits:**
[Multicallable](/src/utils/Multicallable.sol/contract.Multicallable.md)

Keep Factory.


## State Variables
### keepTemplate
-----------------------------------------------------------------------
Immutables
-----------------------------------------------------------------------


```solidity
Keep internal immutable keepTemplate;
```


## Functions
### constructor

-----------------------------------------------------------------------
Constructor
-----------------------------------------------------------------------


```solidity
constructor(Keep _keepTemplate) payable;
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
event Deployed(Keep indexed keep, bytes32 name, address[] signers, uint256 threshold);
```

