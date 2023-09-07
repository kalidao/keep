// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {Multicallable} from "../../utils/Multicallable.sol";
import {IKeep} from "../../utils/interfaces/IKeep.sol";

/// @title Mint Manager
/// @notice ERC1155 token ID mint permission manager.
contract MintManager is Multicallable {
    event Authorized(
        address indexed src,
        address indexed usr,
        uint256 indexed id,
        bool on
    );

    error Unauthorized();

    mapping(address => mapping(address => mapping(uint256 => bool)))
        public approved;

    function authorize(
        address usr,
        uint256 id,
        bool on
    ) public payable virtual {
        approved[msg.sender][usr][id] = on;

        emit Authorized(msg.sender, usr, id, on);
    }

    function mint(
        address src,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) public payable virtual {
        if (!approved[src][msg.sender][id]) revert Unauthorized();

        IKeep(src).mint(to, id, amount, data);
    }
}
