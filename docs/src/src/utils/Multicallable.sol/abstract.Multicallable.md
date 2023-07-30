# Multicallable
[Git Source](https://github.com/kalidao/keep/blob/4ba354e122c2e294d53e3539ad035bb2950c6c96/src/utils/Multicallable.sol)

**Author:**
Modified from Solady (https://github.com/vectorized/solady/blob/main/src/utils/Multicallable.sol)

Contract that enables a single call to call multiple methods on itself.


## Functions
### multicall

*Apply `DELEGATECALL` with the current contract to each calldata in `data`,
and store the `abi.encode` formatted results of each `DELEGATECALL` into `results`.
If any of the `DELEGATECALL`s reverts, the entire context is reverted,
and the error is bubbled up.
For efficiency, this function will directly return the results, terminating the context.
If called internally, it must be called at the end of a function
that returns `(bytes[] memory)`.*


```solidity
function multicall(bytes[] calldata data) public payable virtual returns (bytes[] memory);
```

