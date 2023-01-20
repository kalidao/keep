# LibClone
[Git Source](https://github.com/kalidao/keep/blob/bf21b4d1d146ef800f17003b87f2cf6914c6539e/src/utils/LibClone.sol)

**Author:**
Modified from Solady (https://github.com/Vectorized/solady/blob/main/src/utils/LibClone.sol)

Minimal proxy library with immutable args operations.


## Functions
### cloneDeterministic

-----------------------------------------------------------------------
Clone Operations
-----------------------------------------------------------------------

*Deploys a deterministic clone of `implementation`,
using immutable arguments encoded in `data`, with `salt`.*


```solidity
function cloneDeterministic(address implementation, bytes memory data, bytes32 salt)
    internal
    returns (address instance);
```

### predictDeterministicAddress

*Returns the address of the deterministic clone of
`implementation` using immutable arguments encoded in `data`, with `salt`, by `deployer`.*


```solidity
function predictDeterministicAddress(address implementation, bytes memory data, bytes32 salt, address deployer)
    internal
    pure
    returns (address predicted);
```

## Errors
### DeploymentFailed
-----------------------------------------------------------------------
Custom Errors
-----------------------------------------------------------------------

*Unable to deploy the clone.*


```solidity
error DeploymentFailed();
```

