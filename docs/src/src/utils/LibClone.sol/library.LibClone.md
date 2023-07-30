# LibClone
[Git Source](https://github.com/kalidao/keep/blob/4ba354e122c2e294d53e3539ad035bb2950c6c96/src/utils/LibClone.sol)

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

