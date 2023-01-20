# DataRoom
[Git Source](https://github.com/kalidao/keep/blob/1979341a5a2118c8b67dae50ac448106c85bacac/src/extensions/storage/DataRoom.sol)

**Author:**
audsssy.eth

Data room for on-chain orgs.


## State Variables
### room
-----------------------------------------------------------------------
DataRoom Storage
-----------------------------------------------------------------------


```solidity
mapping(address => string[]) public room;
```


### authorized

```solidity
mapping(address => mapping(address => bool)) public authorized;
```


## Functions
### constructor

-----------------------------------------------------------------------
Constructor
-----------------------------------------------------------------------


```solidity
constructor() payable;
```

### setRecord

-----------------------------------------------------------------------
DataRoom Logic
-----------------------------------------------------------------------

Record data on-chain.

*Calls are permissioned to those authorized to access a Room.*


```solidity
function setRecord(address account, string[] calldata data) public payable virtual;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|Identifier of a Room.|
|`data`|`string[]`|The data to record.|


### getRoom

Retrieve data from a Room.


```solidity
function getRoom(address account) public view virtual returns (string[] memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|Identifier of a Room.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string[]`|The array of data associated with a Room.|


### setPermission

Initialize a Room or authorize users to a Room.

*Calls are permissioned to the authorized accounts of a Room.*


```solidity
function setPermission(address account, address[] calldata users, bool[] calldata authorize) public payable virtual;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|Identifier of a Room.|
|`users`|`address[]`|Users to be authorized or deauthorized to access a Room.|
|`authorize`|`bool[]`|Authorization status.|


### _authorized

-----------------------------------------------------------------------
Internal Functions
-----------------------------------------------------------------------

Helper function to check access to a Room.


```solidity
function _authorized(address account, address user) internal view virtual returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|Identifier of a Room.|
|`user`|`address`|The user in question.|


## Events
### PermissionSet
-----------------------------------------------------------------------
Events
-----------------------------------------------------------------------


```solidity
event PermissionSet(address indexed dao, address indexed account, bool permissioned);
```

### RecordSet

```solidity
event RecordSet(address indexed dao, string data, address indexed caller);
```

## Errors
### Unauthorized
-----------------------------------------------------------------------
Custom Errors
-----------------------------------------------------------------------


```solidity
error Unauthorized();
```

### LengthMismatch

```solidity
error LengthMismatch();
```

### InvalidRoom

```solidity
error InvalidRoom();
```

