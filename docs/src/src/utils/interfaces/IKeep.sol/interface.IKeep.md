# IKeep
[Git Source](https://github.com/kalidao/keep/blob/4ba354e122c2e294d53e3539ad035bb2950c6c96/src/utils/interfaces/IKeep.sol)


## Functions
### DOMAIN_SEPARATOR


```solidity
function DOMAIN_SEPARATOR() external view returns (bytes32);
```

### balanceOf


```solidity
function balanceOf(address, uint256) external view returns (uint256);
```

### balanceOfBatch


```solidity
function balanceOfBatch(address[] memory owners, uint256[] memory ids)
    external
    view
    returns (uint256[] memory balances);
```

### burn


```solidity
function burn(address from, uint256 id, uint256 amount) external payable;
```

### checkpoints


```solidity
function checkpoints(address, uint256, uint256) external view returns (uint40 fromTimestamp, uint216 votes);
```

### delegate


```solidity
function delegate(address delegatee, uint256 id) external payable;
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
) external payable;
```

### delegates


```solidity
function delegates(address account, uint256 id) external view returns (address);
```

### execute


```solidity
function execute(uint8 op, address to, uint256 value, bytes memory data, Signature[] memory sigs) external payable;
```

### getCurrentVotes


```solidity
function getCurrentVotes(address account, uint256 id) external view returns (uint256);
```

### getPastVotes


```solidity
function getPastVotes(address account, uint256 id, uint256 timestamp) external view returns (uint256);
```

### getPriorVotes


```solidity
function getPriorVotes(address account, uint256 id, uint256 timestamp) external view returns (uint256);
```

### getVotes


```solidity
function getVotes(address account, uint256 id) external view returns (uint256);
```

### initialize


```solidity
function initialize(Call[] memory calls, address[] memory signers, uint256 threshold) external payable;
```

### isApprovedForAll


```solidity
function isApprovedForAll(address, address) external view returns (bool);
```

### mint


```solidity
function mint(address to, uint256 id, uint256 amount, bytes memory data) external payable;
```

### multicall


```solidity
function multicall(bytes[] memory data) external payable returns (bytes[] memory);
```

### multirelay


```solidity
function multirelay(Call[] memory calls) external payable;
```

### name


```solidity
function name() external pure returns (string memory);
```

### nonce


```solidity
function nonce() external view returns (uint120);
```

### nonces


```solidity
function nonces(address) external view returns (uint256);
```

### numCheckpoints


```solidity
function numCheckpoints(address, uint256) external view returns (uint256);
```

### onERC1155BatchReceived


```solidity
function onERC1155BatchReceived(address, address, uint256[] memory, uint256[] memory, bytes memory)
    external
    payable
    returns (bytes4);
```

### onERC1155Received


```solidity
function onERC1155Received(address, address, uint256, uint256, bytes memory) external payable returns (bytes4);
```

### onERC721Received


```solidity
function onERC721Received(address, address, uint256, bytes memory) external payable returns (bytes4);
```

### permissioned


```solidity
function permissioned(uint256) external view returns (bool);
```

### permit


```solidity
function permit(address owner, address operator, bool approved, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
    external
    payable;
```

### quorum


```solidity
function quorum() external view returns (uint120);
```

### relay


```solidity
function relay(Call memory call) external payable;
```

### safeBatchTransferFrom


```solidity
function safeBatchTransferFrom(
    address from,
    address to,
    uint256[] memory ids,
    uint256[] memory amounts,
    bytes memory data
) external payable;
```

### safeTransferFrom


```solidity
function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes memory data) external payable;
```

### setApprovalForAll


```solidity
function setApprovalForAll(address operator, bool approved) external payable;
```

### setPermission


```solidity
function setPermission(uint256 id, bool on) external payable;
```

### setQuorum


```solidity
function setQuorum(uint256 threshold) external payable;
```

### setTransferability


```solidity
function setTransferability(uint256 id, bool on) external payable;
```

### setURI


```solidity
function setURI(uint256 id, string memory tokenURI) external payable;
```

### setUserPermission


```solidity
function setUserPermission(address to, uint256 id, bool on) external payable;
```

### supportsInterface


```solidity
function supportsInterface(bytes4 interfaceId) external view returns (bool);
```

### totalSupply


```solidity
function totalSupply(uint256) external view returns (uint256);
```

### transferable


```solidity
function transferable(uint256) external view returns (bool);
```

### uri


```solidity
function uri(uint256 id) external view returns (string memory);
```

### userPermissioned


```solidity
function userPermissioned(address, uint256) external view returns (bool);
```

## Events
### ApprovalForAll

```solidity
event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
```

### DelegateChanged

```solidity
event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate, uint256 id);
```

### DelegateVotesChanged

```solidity
event DelegateVotesChanged(address indexed delegate, uint256 indexed id, uint256 previousBalance, uint256 newBalance);
```

### Executed

```solidity
event Executed(uint256 indexed nonce, uint8 op, address to, uint256 value, bytes data);
```

### Multirelayed

```solidity
event Multirelayed(Call[] calls);
```

### PermissionSet

```solidity
event PermissionSet(address indexed operator, uint256 indexed id, bool on);
```

### QuorumSet

```solidity
event QuorumSet(uint256 threshold);
```

### Relayed

```solidity
event Relayed(Call call);
```

### TransferBatch

```solidity
event TransferBatch(
    address indexed operator, address indexed from, address indexed to, uint256[] ids, uint256[] amounts
);
```

### TransferSingle

```solidity
event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 amount);
```

### TransferabilitySet

```solidity
event TransferabilitySet(address indexed operator, uint256 indexed id, bool on);
```

### URI

```solidity
event URI(string value, uint256 indexed id);
```

### UserPermissionSet

```solidity
event UserPermissionSet(address indexed operator, address indexed to, uint256 indexed id, bool on);
```

## Structs
### Call

```solidity
struct Call {
    uint8 op;
    address to;
    uint256 value;
    bytes data;
}
```

### Signature

```solidity
struct Signature {
    address user;
    uint8 v;
    bytes32 r;
    bytes32 s;
}
```

