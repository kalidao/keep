# KaliFactory
[Git Source](https://github.com/kalidao/keep/blob/4ba354e122c2e294d53e3539ad035bb2950c6c96/src/extensions/dao/KaliFactory.sol)

**Inherits:**
[Multicallable](/src/utils/Multicallable.sol/abstract.Multicallable.md)

Kali Factory.


## State Variables
### kaliTemplate
-----------------------------------------------------------------------
Immutables
-----------------------------------------------------------------------


```solidity
address internal immutable kaliTemplate;
```


## Functions
### constructor

-----------------------------------------------------------------------
Constructor
-----------------------------------------------------------------------


```solidity
constructor(address _kaliTemplate) payable;
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
    Kali indexed kali,
    KeepTokenManager token,
    uint256 tokenId,
    bytes32 name,
    Call[] calls,
    string daoURI,
    uint120[4] govSettings
);
```

