# KeepToken
[Git Source](https://github.com/kalidao/keep/blob/e52b433e668648f92907034179bd28358496fd0a/src/KeepToken.sol)

**Authors:**
Modified from ERC1155V (https://github.com/kalidao/ERC1155V/blob/main/src/ERC1155V.sol), Modified from Compound (https://github.com/compound-finance/compound-protocol/blob/master/contracts/Governance/Comp.sol)

Modern, minimalist, and gas-optimized ERC1155 implementation with Compound-style voting and flexible permissioning scheme.


## State Variables
### balanceOf
-----------------------------------------------------------------------
ERC1155 Storage
-----------------------------------------------------------------------


```solidity
mapping(address => mapping(uint256 => uint256)) public balanceOf;
```


### isApprovedForAll

```solidity
mapping(address => mapping(address => bool)) public isApprovedForAll;
```


### MALLEABILITY_THRESHOLD
-----------------------------------------------------------------------
EIP-712 Storage/Logic
-----------------------------------------------------------------------


```solidity
bytes32 internal constant MALLEABILITY_THRESHOLD = 0x7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0;
```


### nonces

```solidity
mapping(address => uint256) public nonces;
```


### SIGN_KEY

```solidity
uint256 internal constant SIGN_KEY = uint32(0x6c4b5546);
```


### totalSupply

```solidity
mapping(uint256 => uint256) public totalSupply;
```


### transferable

```solidity
mapping(uint256 => bool) public transferable;
```


### permissioned

```solidity
mapping(uint256 => bool) public permissioned;
```


### userPermissioned

```solidity
mapping(address => mapping(uint256 => bool)) public userPermissioned;
```


### _delegates
-----------------------------------------------------------------------
Checkpoint Storage
-----------------------------------------------------------------------


```solidity
mapping(address => mapping(uint256 => address)) internal _delegates;
```


### numCheckpoints

```solidity
mapping(address => mapping(uint256 => uint256)) public numCheckpoints;
```


### checkpoints

```solidity
mapping(address => mapping(uint256 => mapping(uint256 => Checkpoint))) public checkpoints;
```


## Functions
### DOMAIN_SEPARATOR


```solidity
function DOMAIN_SEPARATOR() public view virtual returns (bytes32);
```

### _recoverSig


```solidity
function _recoverSig(bytes32 hash, address signer, uint8 v, bytes32 r, bytes32 s) internal view virtual;
```

### name

-----------------------------------------------------------------------
Metadata Logic
-----------------------------------------------------------------------


```solidity
function name() public pure virtual returns (string memory);
```

### supportsInterface

-----------------------------------------------------------------------
ERC165 Logic
-----------------------------------------------------------------------


```solidity
function supportsInterface(bytes4 interfaceId) public view virtual returns (bool);
```

### balanceOfBatch

-----------------------------------------------------------------------
ERC1155 Logic
-----------------------------------------------------------------------


```solidity
function balanceOfBatch(address[] calldata owners, uint256[] calldata ids)
    public
    view
    virtual
    returns (uint256[] memory balances);
```

### setApprovalForAll


```solidity
function setApprovalForAll(address operator, bool approved) public payable virtual;
```

### safeTransferFrom


```solidity
function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata data)
    public
    payable
    virtual;
```

### safeBatchTransferFrom


```solidity
function safeBatchTransferFrom(
    address from,
    address to,
    uint256[] calldata ids,
    uint256[] calldata amounts,
    bytes calldata data
) public payable virtual;
```

### permit

-----------------------------------------------------------------------
EIP-2612-style Permit Logic
-----------------------------------------------------------------------


```solidity
function permit(address owner, address operator, bool approved, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
    public
    payable
    virtual;
```

### getVotes

-----------------------------------------------------------------------
Checkpoint Logic
-----------------------------------------------------------------------


```solidity
function getVotes(address account, uint256 id) public view virtual returns (uint256);
```

### getCurrentVotes


```solidity
function getCurrentVotes(address account, uint256 id) public view virtual returns (uint256);
```

### getPastVotes


```solidity
function getPastVotes(address account, uint256 id, uint256 timestamp) public view virtual returns (uint256);
```

### getPriorVotes


```solidity
function getPriorVotes(address account, uint256 id, uint256 timestamp) public view virtual returns (uint256);
```

### delegates

-----------------------------------------------------------------------
Delegation Logic
-----------------------------------------------------------------------


```solidity
function delegates(address account, uint256 id) public view virtual returns (address);
```

### delegate


```solidity
function delegate(address delegatee, uint256 id) public payable virtual;
```

### delegateBySig


```solidity
function delegateBySig(
    address delegator,
    address delegatee,
    uint256 id,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
) public payable virtual;
```

### _delegate


```solidity
function _delegate(address delegator, address delegatee, uint256 id) internal virtual;
```

### _moveDelegates


```solidity
function _moveDelegates(address srcRep, address dstRep, uint256 id, uint256 amount) internal virtual;
```

### _writeCheckpoint


```solidity
function _writeCheckpoint(address delegatee, uint256 id, uint256 nCheckpoints, uint256 oldVotes, uint256 newVotes)
    internal
    virtual;
```

### _safeCastTo40

-----------------------------------------------------------------------
Safecast Logic
-----------------------------------------------------------------------


```solidity
function _safeCastTo40(uint256 x) internal pure virtual returns (uint40);
```

### _safeCastTo216


```solidity
function _safeCastTo216(uint256 x) internal pure virtual returns (uint216);
```

### _mint

-----------------------------------------------------------------------
Internal Mint/Burn Logic
-----------------------------------------------------------------------


```solidity
function _mint(address to, uint256 id, uint256 amount, bytes calldata data) internal virtual;
```

### _burn


```solidity
function _burn(address from, uint256 id, uint256 amount) internal virtual;
```

### _setTransferability

-----------------------------------------------------------------------
Internal Permission Logic
-----------------------------------------------------------------------


```solidity
function _setTransferability(uint256 id, bool on) internal virtual;
```

### _setPermission


```solidity
function _setPermission(uint256 id, bool on) internal virtual;
```

### _setUserPermission


```solidity
function _setUserPermission(address to, uint256 id, bool on) internal virtual;
```

## Events
### DelegateChanged
-----------------------------------------------------------------------
Events
-----------------------------------------------------------------------


```solidity
event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate, uint256 id);
```

### DelegateVotesChanged

```solidity
event DelegateVotesChanged(address indexed delegate, uint256 indexed id, uint256 previousBalance, uint256 newBalance);
```

### TransferSingle

```solidity
event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 amount);
```

### TransferBatch

```solidity
event TransferBatch(
    address indexed operator, address indexed from, address indexed to, uint256[] ids, uint256[] amounts
);
```

### ApprovalForAll

```solidity
event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
```

### TransferabilitySet

```solidity
event TransferabilitySet(address indexed operator, uint256 indexed id, bool on);
```

### PermissionSet

```solidity
event PermissionSet(address indexed operator, uint256 indexed id, bool on);
```

### UserPermissionSet

```solidity
event UserPermissionSet(address indexed operator, address indexed to, uint256 indexed id, bool on);
```

### URI

```solidity
event URI(string value, uint256 indexed id);
```

## Errors
### InvalidSig
-----------------------------------------------------------------------
Custom Errors
-----------------------------------------------------------------------


```solidity
error InvalidSig();
```

### LengthMismatch

```solidity
error LengthMismatch();
```

### Unauthorized

```solidity
error Unauthorized();
```

### NonTransferable

```solidity
error NonTransferable();
```

### NotPermitted

```solidity
error NotPermitted();
```

### UnsafeRecipient

```solidity
error UnsafeRecipient();
```

### InvalidRecipient

```solidity
error InvalidRecipient();
```

### ExpiredSig

```solidity
error ExpiredSig();
```

### Undetermined

```solidity
error Undetermined();
```

### Overflow

```solidity
error Overflow();
```

## Structs
### Checkpoint

```solidity
struct Checkpoint {
    uint40 fromTimestamp;
    uint216 votes;
}
```

