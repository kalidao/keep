# ERC1155TokenReceiver
[Git Source](https://github.com/kalidao/keep/blob/4ba354e122c2e294d53e3539ad035bb2950c6c96/src/KeepToken.sol)

**Author:**
Modified from Solbase (https://github.com/Sol-DAO/solbase/blob/main/src/tokens/ERC1155/ERC1155.sol)

ERC1155 interface to receive tokens.


## Functions
### onERC1155Received


```solidity
function onERC1155Received(address, address, uint256, uint256, bytes calldata)
    public
    payable
    virtual
    returns (bytes4);
```

### onERC1155BatchReceived


```solidity
function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
    public
    payable
    virtual
    returns (bytes4);
```

