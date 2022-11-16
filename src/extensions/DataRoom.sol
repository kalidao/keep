// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

/// @title DataRoom
/// @notice Data room for on-chain entities.
/// @author audsssy.eth | KaliCo LLC

struct Data {
    Location locationType;
    string content;
    address owner;
}

enum Location {
    SHARED,
    USER
}

contract DataRoom {
    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event OperatorSet (
        Location location,
        address indexed operator,
        bool status
    );

    event RecordSet (
        Location location,
        string indexed data,
        address indexed owner
    );  
   
    /// -----------------------------------------------------------------------
    /// DataRoom Storage
    /// -----------------------------------------------------------------------

    address public operator;

    mapping(Location => Data[]) public collection;

    mapping(address => bool) public authorized;

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor() payable {
        operator = msg.sender;

        emit OperatorSet(Location.SHARED, operator, true);
    }

    /// -----------------------------------------------------------------------
    /// DataRoom Logic
    /// -----------------------------------------------------------------------

    /// @notice Record data on-chain.
    /// @param data The data to record on-chain.
    /// @dev Calls are permissioned to the operator of a given storage location.
    function setRecord(Location location, string calldata data) 
        external 
        payable  
    {
        if (location == Location.SHARED) {
            require(msg.sender == operator, "NotOperator");
            collection[location].push(
                Data({
                    locationType: location,
                    content: data,
                    owner: msg.sender
                })
            );
            emit RecordSet(location, data, msg.sender);
        } else {
            require(msg.sender == operator || authorized[msg.sender], "NotAuthorized");
            collection[location].push(
                Data({
                    locationType: location,
                    content: data,
                    owner: msg.sender
                })
            );
            emit RecordSet(location, data, msg.sender);
        }
    }

    /// @notice Retrieve a collection of Data.
    /// @param location The Location to retrieve collection with.
    /// @return data An array of Data.
    function getCollection(Location location) 
        external 
        view 
        returns (Data[] memory data) 
    {
        data = collection[location];
    }

    /// -----------------------------------------------------------------------
    /// Operator Functions
    /// -----------------------------------------------------------------------

    /// @notice Record data on-chain.
    /// @param location The record location to assign operator to.
    /// @param account The account to assign as operator.
    /// @dev Calls are permissioned to the operator of a given room.
    function setOperator(Location location, address account) 
        external 
        payable 
    {
        if (location == Location.SHARED) {
            require(msg.sender == operator, "NotOperator");
            operator = account;
            emit OperatorSet(location, operator, true);
        } else {
            require(msg.sender == operator || authorized[msg.sender], "NotAuthorized");
            authorized[account] = !authorized[account];
            emit OperatorSet(location, account, authorized[account]);
        }
    }
}