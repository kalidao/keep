# KaliFactory
[Git Source](https://github.com/kalidao/keep/blob/bf21b4d1d146ef800f17003b87f2cf6914c6539e/src/extensions/dao/KaliFactory.sol)

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

