# KaliFactory
[Git Source](https://github.com/kalidao/keep/blob/1979341a5a2118c8b67dae50ac448106c85bacac/src/extensions/dao/KaliFactory.sol)

**Inherits:**
[Multicallable](/src/utils/Multicallable.sol/contract.Multicallable.md)

Kali Factory.


## State Variables
### kaliTemplate
-----------------------------------------------------------------------
Immutables
-----------------------------------------------------------------------


```solidity
Kali internal immutable kaliTemplate;
```


## Functions
### constructor

-----------------------------------------------------------------------
Constructor
-----------------------------------------------------------------------


```solidity
constructor(Kali _kaliTemplate) payable;
```

### determineKali

-----------------------------------------------------------------------
Deployment Logic
-----------------------------------------------------------------------


```solidity
function determineKali(KeepTokenManager token, uint256 tokenId, bytes32 name) public view virtual returns (address);
```

### deployKali


```solidity
function deployKali(
    KeepTokenManager _token,
    uint256 _tokenId,
    bytes32 _name,
    Call[] calldata _calls,
    string calldata _daoURI,
    uint120[4] calldata _govSettings
) public payable virtual;
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
event Deployed(
    Kali kali,
    KeepTokenManager token,
    uint256 tokenId,
    bytes32 name,
    Call[] calls,
    string daoURI,
    uint120[4] govSettings
);
```

