# Multicallable
[Git Source](https://github.com/kalidao/keep/blob/1979341a5a2118c8b67dae50ac448106c85bacac/src/utils/Multicallable.sol)

**Author:**
Modified from Solady (https://github.com/vectorized/solady/blob/main/src/utils/Multicallable.sol)

Contract that enables a single call to call multiple methods on itself.

*WARNING!
Multicallable is NOT SAFE for use in contracts with checks / requires on `msg.value`
(e.g. in NFT minting / auction contracts) without a suitable nonce mechanism.
It WILL open up your contract to double-spend vulnerabilities / exploits.
See: (https://www.paradigm.xyz/2021/08/two-rights-might-make-a-wrong/)*


## Functions
### multicall

*Apply `DELEGATECALL` with the current contract to each calldata in `data`,
and store the `abi.encode` formatted results of each `DELEGATECALL` into `results`.
If any of the `DELEGATECALL`s reverts, the entire transaction is reverted,
and the error is bubbled up.*


```solidity
function multicall(bytes[] calldata data) public payable virtual returns (bytes[] memory);
```

