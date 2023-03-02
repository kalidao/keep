// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {KeepTokenManager} from "../utils/KeepTokenManager.sol";
import {Multicallable} from "../../utils/Multicallable.sol";

/// @title Mint Manager
/// @notice ERC1155 token ID mint permission manager.
/// @author z0r0z.eth
contract MintManager is Multicallable {
    event Approved(
        address indexed source,
        address indexed manager,
        uint256 id,
        bool approve
    );

    error Unauthorized();

    mapping(address => mapping(address => mapping(uint256 => bool)))
        public approved;

    function approve(
        address manager,
        uint256 id,
        bool on
    ) public payable virtual {
        approved[msg.sender][manager][id] = on;

        emit Approved(msg.sender, manager, id, on);
    }

    function mint(
        address source,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) public payable virtual {
        if (!approved[source][msg.sender][id]) revert Unauthorized();

        KeepTokenManager(source).mint(to, id, amount, data);
    }
}
