# Keep
[Git Source](https://github.com/kalidao/keep/blob/4ba354e122c2e294d53e3539ad035bb2950c6c96/src/Keep.sol)

**Inherits:**
[ERC1155TokenReceiver](/src/KeepToken.sol/abstract.ERC1155TokenReceiver.md), [KeepToken](/src/KeepToken.sol/abstract.KeepToken.md), [Multicallable](/src/utils/Multicallable.sol/abstract.Multicallable.md)


## State Variables
### CORE_KEY
-----------------------------------------------------------------------
Keep Storage/Logic
-----------------------------------------------------------------------

*Core ID key permission.*


```solidity
uint256 internal immutable CORE_KEY = uint32(type(KeepToken).interfaceId);
```


### uriFetcher
*Default metadata fetcher for `uri()`.*


```solidity
Keep internal immutable uriFetcher;
```


### nonce
*Record of states verifying `execute()`.*


```solidity
uint120 public nonce;
```


### quorum
*SIGN_KEY threshold to `execute()`.*


```solidity
uint120 public quorum;
```


### _uris
*Internal ID metadata mapping.*


```solidity
mapping(uint256 => string) internal _uris;
```


## Functions
### uri

*ID metadata fetcher.*


```solidity
function uri(uint256 id) public view virtual returns (string memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`id`|`uint256`|ID to fetch from.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|tokenURI Metadata.|


### _authorized

*Access control check for ID key balance holders.
Initializes with `address(this)` having implicit permission
without writing to storage by checking `totalSupply()` is zero.
Otherwise, this permission can be set to additional accounts,
including retaining `address(this)`, via `mint()`.*


```solidity
function _authorized() internal view virtual returns (bool);
```

### supportsInterface

-----------------------------------------------------------------------
ERC165 Logic
-----------------------------------------------------------------------

*ERC165 interface detection.*


```solidity
function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`interfaceId`|`bytes4`|ID to check.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Fetch detection success.|


### onERC721Received

-----------------------------------------------------------------------
ERC721 Receiver Logic
-----------------------------------------------------------------------


```solidity
function onERC721Received(address, address, uint256, bytes calldata) public payable virtual returns (bytes4);
```

### constructor

-----------------------------------------------------------------------
Initialization Logic
-----------------------------------------------------------------------

Create Keep template.


```solidity
constructor(Keep _uriFetcher) payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_uriFetcher`|`Keep`|Metadata default.|


### initialize

Initialize Keep configuration.


```solidity
function initialize(Call[] calldata calls, address[] calldata signers, uint256 threshold) public payable virtual;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`calls`|`Call[]`|Initial Keep operations.|
|`signers`|`address[]`|Initial signer set.|
|`threshold`|`uint256`|Initial quorum.|


### execute

-----------------------------------------------------------------------
Execution Logic
-----------------------------------------------------------------------

Execute operation from Keep with signatures.


```solidity
function execute(Operation op, address to, uint256 value, bytes calldata data, Signature[] calldata sigs)
    public
    payable
    virtual;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`op`|`Operation`|Enum operation to execute.|
|`to`|`address`|Address to send operation to.|
|`value`|`uint256`|Amount of ETH to send in operation.|
|`data`|`bytes`|Payload to send in operation.|
|`sigs`|`Signature[]`|Array of Keep signatures in ascending order by addresses.|


### relay

Relay operation from Keep via `execute()` or as ID key holder.


```solidity
function relay(Call calldata call) public payable virtual;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`call`|`Call`|Keep operation as struct of `op, to, value, data`.|


### multirelay

Relay operations from Keep via `execute()` or as ID key holder.


```solidity
function multirelay(Call[] calldata calls) public payable virtual;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`calls`|`Call[]`|Keep operations as struct arrays of `op, to, value, data`.|


### _execute


```solidity
function _execute(Operation op, address to, uint256 value, bytes memory data) internal virtual;
```

### mint

-----------------------------------------------------------------------
Mint/Burn Logic
-----------------------------------------------------------------------

ID minter.


```solidity
function mint(address to, uint256 id, uint256 amount, bytes calldata data) public payable virtual;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address`|Recipient of mint.|
|`id`|`uint256`|ID to mint.|
|`amount`|`uint256`|ID balance to mint.|
|`data`|`bytes`|Optional data payload.|


### burn

ID burner.


```solidity
function burn(address from, uint256 id, uint256 amount) public payable virtual;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`from`|`address`|Account to burn from.|
|`id`|`uint256`|ID to burn.|
|`amount`|`uint256`|Balance to burn.|


### setQuorum

-----------------------------------------------------------------------
Threshold Setting Logic
-----------------------------------------------------------------------

Update Keep quorum threshold.


```solidity
function setQuorum(uint256 threshold) public payable virtual;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`threshold`|`uint256`|Signature threshold for `execute()`.|


### setTransferability

-----------------------------------------------------------------------
ID Setting Logic
-----------------------------------------------------------------------

ID transferability setting.


```solidity
function setTransferability(uint256 id, bool on) public payable virtual;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`id`|`uint256`|ID to set transferability for.|
|`on`|`bool`|Transferability setting.|


### setPermission

ID transfer permission toggle.

*This sets account-based ID restriction globally.*


```solidity
function setPermission(uint256 id, bool on) public payable virtual;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`id`|`uint256`|ID to set permission for.|
|`on`|`bool`|Permission setting.|


### setUserPermission

ID transfer permission setting.

*This sets account-based ID restriction specifically.*


```solidity
function setUserPermission(address to, uint256 id, bool on) public payable virtual;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address`|Account to set permission for.|
|`id`|`uint256`|ID to set permission for.|
|`on`|`bool`|Permission setting.|


### setURI

ID metadata setting.


```solidity
function setURI(uint256 id, string calldata tokenURI) public payable virtual;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`id`|`uint256`|ID to set metadata for.|
|`tokenURI`|`string`|Metadata setting.|


## Events
### Executed
-----------------------------------------------------------------------
Events
-----------------------------------------------------------------------

*Emitted when Keep executes call.*


```solidity
event Executed(uint256 indexed nonce, Operation op, address to, uint256 value, bytes data);
```

### Relayed
*Emitted when Keep relays call.*


```solidity
event Relayed(Call call);
```

### Multirelayed
*Emitted when Keep relays calls.*


```solidity
event Multirelayed(Call[] calls);
```

### QuorumSet
*Emitted when quorum threshold is updated.*


```solidity
event QuorumSet(uint256 threshold);
```

## Errors
### AlreadyInit
-----------------------------------------------------------------------
Custom Errors
-----------------------------------------------------------------------

*Throws if `initialize()` is called more than once.*


```solidity
error AlreadyInit();
```

### QuorumOverSupply
*Throws if quorum exceeds `totalSupply(SIGN_KEY)`.*


```solidity
error QuorumOverSupply();
```

### InvalidThreshold
*Throws if quorum with `threshold = 0` is set.*


```solidity
error InvalidThreshold();
```

### ExecuteFailed
*Throws if `execute()` doesn't complete operation.*


```solidity
error ExecuteFailed();
```

