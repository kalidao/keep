# Proposal
[Git Source](https://github.com/kalidao/keep/blob/4ba354e122c2e294d53e3539ad035bb2950c6c96/src/extensions/dao/Kali.sol)


```solidity
struct Proposal {
    uint256 prevProposal;
    bytes32 proposalHash;
    address proposer;
    uint40 creationTime;
    uint216 yesVotes;
    uint216 noVotes;
}
```

