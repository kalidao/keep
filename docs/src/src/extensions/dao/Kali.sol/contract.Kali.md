# Kali
[Git Source](https://github.com/kalidao/keep/blob/bf21b4d1d146ef800f17003b87f2cf6914c6539e/src/extensions/dao/Kali.sol)

**Inherits:**
[ERC1155TokenReceiver](/src/KeepToken.sol/contract.ERC1155TokenReceiver.md), [Multicallable](/src/utils/Multicallable.sol/contract.Multicallable.md), ReentrancyGuard


## State Variables
### MALLEABILITY_THRESHOLD
-----------------------------------------------------------------------
DAO Storage/Logic
-----------------------------------------------------------------------


```solidity
bytes32 internal constant MALLEABILITY_THRESHOLD = 0x7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0;
```


### currentSponsoredProposal

```solidity
uint256 internal currentSponsoredProposal;
```


### proposalCount

```solidity
uint256 public proposalCount;
```


### daoURI

```solidity
string public daoURI;
```


### votingPeriod

```solidity
uint120 public votingPeriod;
```


### gracePeriod

```solidity
uint120 public gracePeriod;
```


### quorum

```solidity
uint8 public quorum;
```


### supermajority

```solidity
uint8 public supermajority;
```


### extensions

```solidity
mapping(address => bool) public extensions;
```


### proposals

```solidity
mapping(uint256 => Proposal) public proposals;
```


### proposalStates

```solidity
mapping(uint256 => ProposalState) public proposalStates;
```


### proposalVoteTypes

```solidity
mapping(ProposalType => VoteType) public proposalVoteTypes;
```


### voted

```solidity
mapping(uint256 => mapping(address => bool)) public voted;
```


### lastYesVote

```solidity
mapping(address => uint256) public lastYesVote;
```


## Functions
### token


```solidity
function token() public pure virtual returns (KeepTokenManager tkn);
```

### tokenId


```solidity
function tokenId() public pure virtual returns (uint256 id);
```

### name


```solidity
function name() public pure virtual returns (string memory);
```

### _fetchImmutable


```solidity
function _fetchImmutable(uint256 place) internal pure virtual returns (uint256 ref);
```

### supportsInterface

-----------------------------------------------------------------------
ERC165 Logic
-----------------------------------------------------------------------


```solidity
function supportsInterface(bytes4 interfaceId) public view virtual returns (bool);
```

### onERC721Received

-----------------------------------------------------------------------
ERC721 Receiver Logic
-----------------------------------------------------------------------


```solidity
function onERC721Received(address, address, uint256, bytes calldata) public payable virtual returns (bytes4);
```

### initialize

-----------------------------------------------------------------------
Initialization Logic
-----------------------------------------------------------------------


```solidity
function initialize(Call[] calldata _calls, string calldata _daoURI, uint120[4] calldata _govSettings)
    public
    payable
    virtual;
```

### DOMAIN_SEPARATOR

-----------------------------------------------------------------------
EIP-712 Logic
-----------------------------------------------------------------------


```solidity
function DOMAIN_SEPARATOR() public view virtual returns (bytes32);
```

### propose

-----------------------------------------------------------------------
Proposal Logic
-----------------------------------------------------------------------


```solidity
function propose(ProposalType proposalType, string calldata description, Call[] calldata calls)
    public
    payable
    virtual
    returns (uint256 proposal);
```

### cancelProposal


```solidity
function cancelProposal(uint256 proposal) public payable virtual;
```

### sponsorProposal


```solidity
function sponsorProposal(uint256 proposal) public payable virtual;
```

### vote

-----------------------------------------------------------------------
Voting Logic
-----------------------------------------------------------------------


```solidity
function vote(uint256 proposal, bool approve, bytes32 details) public payable virtual;
```

### voteBySig


```solidity
function voteBySig(address user, uint256 proposal, bool approve, bytes32 details, uint8 v, bytes32 r, bytes32 s)
    public
    payable
    virtual;
```

### _vote


```solidity
function _vote(address user, uint256 proposal, bool approve, bytes32 details) internal virtual;
```

### processProposal

-----------------------------------------------------------------------
Processing Logic
-----------------------------------------------------------------------


```solidity
function processProposal(
    uint256 proposal,
    ProposalType proposalType,
    string calldata description,
    Call[] calldata calls
) public payable virtual nonReentrant returns (bool passed);
```

### _countVotes


```solidity
function _countVotes(VoteType voteType, uint256 yesVotes, uint256 noVotes)
    internal
    view
    virtual
    returns (bool passed);
```

### _execute

-----------------------------------------------------------------------
Execution Logic
-----------------------------------------------------------------------


```solidity
function _execute(Operation op, address to, uint256 value, bytes memory data) internal virtual;
```

### _recoverSig

-----------------------------------------------------------------------
Signature Verification Logic
-----------------------------------------------------------------------


```solidity
function _recoverSig(bytes32 hash, address user, uint8 v, bytes32 r, bytes32 s) internal view virtual;
```

### _safeCastTo40


```solidity
function _safeCastTo40(uint256 x) internal pure virtual returns (uint40);
```

### onlyExtension

-----------------------------------------------------------------------
Extension Logic
-----------------------------------------------------------------------


```solidity
modifier onlyExtension();
```

### relay


```solidity
function relay(Call calldata call) public payable virtual onlyExtension nonReentrant;
```

### mint


```solidity
function mint(KeepTokenManager source, address to, uint256 id, uint256 amount, bytes calldata data)
    public
    payable
    virtual
    onlyExtension
    nonReentrant;
```

### burn


```solidity
function burn(KeepTokenManager source, address from, uint256 id, uint256 amount)
    public
    payable
    virtual
    onlyExtension
    nonReentrant;
```

### setTransferability


```solidity
function setTransferability(KeepTokenManager source, uint256 id, bool on)
    public
    payable
    virtual
    onlyExtension
    nonReentrant;
```

### setExtension


```solidity
function setExtension(address extension, bool on) public payable virtual;
```

### setURI


```solidity
function setURI(string calldata _daoURI) public payable virtual onlyExtension;
```

### deleteProposal


```solidity
function deleteProposal(uint256 proposal) public payable virtual;
```

### updateGovSettings


```solidity
function updateGovSettings(
    uint256 _votingPeriod,
    uint256 _gracePeriod,
    uint256 _quorum,
    uint256 _supermajority,
    uint256[2] calldata _typeSetting
) public payable virtual;
```

## Events
### NewProposal
-----------------------------------------------------------------------
Events
-----------------------------------------------------------------------


```solidity
event NewProposal(
    address indexed proposer,
    uint256 indexed proposal,
    ProposalType proposalType,
    string description,
    Call[] calls,
    uint256 creationTime,
    bool selfSponsor
);
```

### ProposalCancelled

```solidity
event ProposalCancelled(address indexed proposer, uint256 indexed proposal);
```

### ProposalSponsored

```solidity
event ProposalSponsored(address indexed sponsor, uint256 indexed proposal);
```

### VoteCast

```solidity
event VoteCast(address indexed voter, uint256 indexed proposal, bool approve, uint256 weight, bytes32 details);
```

### ProposalProcessed

```solidity
event ProposalProcessed(uint256 indexed proposal, bool passed);
```

### ExtensionSet

```solidity
event ExtensionSet(address indexed extension, bool on);
```

### URIset

```solidity
event URIset(string daoURI);
```

### GovSettingsUpdated

```solidity
event GovSettingsUpdated(
    uint256 votingPeriod, uint256 gracePeriod, uint256 quorum, uint256 supermajority, uint256[2] typeSetting
);
```

### Executed

```solidity
event Executed(Operation op, address to, uint256 value, bytes data);
```

## Errors
### Initialized
-----------------------------------------------------------------------
Custom Errors
-----------------------------------------------------------------------


```solidity
error Initialized();
```

### PeriodBounds

```solidity
error PeriodBounds();
```

### QuorumMax

```solidity
error QuorumMax();
```

### SupermajorityBounds

```solidity
error SupermajorityBounds();
```

### TypeBounds

```solidity
error TypeBounds();
```

### Unauthorized

```solidity
error Unauthorized();
```

### Sponsored

```solidity
error Sponsored();
```

### InvalidProposal

```solidity
error InvalidProposal();
```

### AlreadyVoted

```solidity
error AlreadyVoted();
```

### InvalidHash

```solidity
error InvalidHash();
```

### PrevNotProcessed

```solidity
error PrevNotProcessed();
```

### VotingNotEnded

```solidity
error VotingNotEnded();
```

### ExecuteFailed

```solidity
error ExecuteFailed();
```

### InvalidSig

```solidity
error InvalidSig();
```

### Overflow

```solidity
error Overflow();
```

