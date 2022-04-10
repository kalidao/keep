// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

/// @notice Ricardian LLC formation interface
interface IRicardianLLC {
    function mintLLC(address to) external payable;
}
