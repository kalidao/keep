// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Ownable} from "../../utils/Ownable.sol";
import {UserOperation} from "../../Keep.sol";

function getURI(address, uint256) returns (string memory) {}

/// @notice Open-ended metadata for ERC1155 and ERC4337 permission fetching.
contract Validator is Ownable(tx.origin) {
    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event PermissionRemoteValidatorSet(
        Validator indexed permissionRemoteValidator
    );

    event URIRemoteValidatorSet(Validator indexed uriRemoteValidator);

    event EntryPointSet(address indexed entryPoint);

    /// -----------------------------------------------------------------------
    /// Remote Storage
    /// -----------------------------------------------------------------------

    Validator internal permissionRemoteValidator;

    Validator internal uriRemoteValidator;

    address public entryPoint;

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor() payable {
        emit EntryPointSet(
            entryPoint = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789
        );
    }

    /// -----------------------------------------------------------------------
    /// Permission Remote Logic
    /// -----------------------------------------------------------------------

    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) public view virtual returns (uint256) {
        return
            permissionRemoteValidator.validateUserOp(
                userOp,
                userOpHash,
                missingAccountFunds
            );
    }

    function setPermissionRemoteValidator(
        Validator _permissionRemoteValidator
    ) public payable virtual onlyOwner {
        permissionRemoteValidator = _permissionRemoteValidator;

        emit PermissionRemoteValidatorSet(_permissionRemoteValidator);
    }

    /// -----------------------------------------------------------------------
    /// URI Remote Logic
    /// -----------------------------------------------------------------------
    function uri(
        address,
        uint256
    ) public view virtual returns (string memory) {}

    function uri(uint256 id) public view virtual returns (string memory) {
        return uriRemoteValidator.uri(msg.sender, id);
    }

    function setURIRemoteValidator(
        Validator _uriRemoteValidator
    ) public payable virtual onlyOwner {
        uriRemoteValidator = _uriRemoteValidator;

        emit URIRemoteValidatorSet(_uriRemoteValidator);
    }

    /// -----------------------------------------------------------------------
    /// Entry Point Logic
    /// -----------------------------------------------------------------------

    function setEntryPoint(
        address _entryPoint
    ) public payable virtual onlyOwner {
        entryPoint = _entryPoint;

        emit EntryPointSet(_entryPoint);
    }
}
