// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {UserOperation} from "../../Keep.sol";
import {Owned} from "../utils/Owned.sol";

/// @notice Open-ended metadata for ERC1155 and ERC4337 permission fetching.
contract Validator is Owned(tx.origin) {
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

    address internal entryPoint;

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
        bytes32 hash,
        uint256 missingAccountFunds
    ) public view virtual returns (uint256) {
        return
            permissionRemoteValidator.validateUserOp(
                userOp,
                hash,
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

    function uri(uint256 id) public view virtual returns (string memory) {
        return uriRemoteValidator.uri(id);
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
