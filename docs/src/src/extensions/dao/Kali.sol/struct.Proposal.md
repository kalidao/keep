# Proposal
[Git Source](https://github.com/kalidao/keep/blob/bf21b4d1d146ef800f17003b87f2cf6914c6539e/src/extensions/dao/Kali.sol)


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

