// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

/// @title DataRoom
/// @notice Data room for on-chain entities.
/// @author audsssy.eth | KaliCo LLC

struct Data {
    Location locationType;
    string content;
}

enum Location {
    ROOM,
    FOLDER
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
        address indexed caller,
        string indexed data
    );

    /// -----------------------------------------------------------------------
    /// Custom Errors
    /// -----------------------------------------------------------------------

    error NotOperator();    
   
    /// -----------------------------------------------------------------------
    /// DataRoom Storage
    /// -----------------------------------------------------------------------

    address public operator;

    mapping(address => Data[]) public collection;

    mapping(address => bool) public status;

    modifier onlyOperator {
        if (msg.sender != operator || !status[msg.sender]) revert NotOperator();

        _;
    }

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor() payable {
        operator = msg.sender;

        emit OperatorSet(Location.ROOM, operator, true);
    }

    /// -----------------------------------------------------------------------
    /// DataRoom Logic
    /// -----------------------------------------------------------------------

    /// @notice Record data on-chain.
    /// @param data The data to record on-chain.
    /// @dev Calls are permissioned to the operator of a given room.
    function setRecord(string calldata data) 
        external 
        payable 
        onlyOperator 
    {
        if (msg.sender == operator) {
            collection[msg.sender].push(
                Data({
                    locationType: Location.ROOM,
                    content: data
                })
            );
            emit RecordSet(Location.ROOM, msg.sender, data);
        } else {
            collection[msg.sender].push(
                Data({
                    locationType: Location.FOLDER,
                    content: data
                })
            );
            emit RecordSet(Location.FOLDER, msg.sender, data);
        }
    }

    /// @notice Retrieve a collection of Data.
    /// @param account The account to retrieve collection with.
    /// @return data An array of Data.
    function getCollection(address account) 
        external 
        view 
        returns (Data[] memory data) 
    {
        data = collection[account];
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
        onlyOperator 
    {
        if (location == Location.ROOM) {
            operator = account;
            emit OperatorSet(location, operator, true);
        } else {
            status[msg.sender] = !status[msg.sender];
            emit OperatorSet(location, msg.sender, status[msg.sender]);
        }
    }
}