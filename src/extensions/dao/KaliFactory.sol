// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {KeepTokenBalances, Multicallable, Call, Kali} from "./Kali.sol";
import {LibClone} from "./../../utils/LibClone.sol";

/// @notice Kali Factory.
contract KaliFactory is Multicallable {
    /// -----------------------------------------------------------------------
    /// Library Usage
    /// -----------------------------------------------------------------------

    using LibClone for address;

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event Deployed(
        Kali kali,
        KeepTokenBalances token,
        uint256 tokenId,
        bytes32 name,
        Call[] calls,
        string daoURI,
        uint120[4] govSettings
    );

    /// -----------------------------------------------------------------------
    /// Immutables
    /// -----------------------------------------------------------------------

    Kali internal immutable kaliTemplate;

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor(Kali _kaliTemplate) payable {
        kaliTemplate = _kaliTemplate;
    }

    /// -----------------------------------------------------------------------
    /// Deployment Logic
    /// -----------------------------------------------------------------------

    function determineKali(
        KeepTokenBalances token,
        uint256 tokenId,
        bytes32 name
    ) public view virtual returns (address) {
        return
            address(kaliTemplate).predictDeterministicAddress(
                abi.encodePacked(token, tokenId, name),
                name,
                address(this)
            );
    }

    function deployKali(
        KeepTokenBalances _token,
        uint256 _tokenId,
        bytes32 _name, // create2 salt.
        Call[] calldata _calls,
        string calldata _daoURI,
        uint120[4] calldata _govSettings
    ) public payable virtual {
        Kali kali = Kali(
            address(kaliTemplate).cloneDeterministic(
                abi.encodePacked(_token, _tokenId, _name),
                _name
            )
        );

        kali.initialize{value: msg.value}(_calls, _daoURI, _govSettings);

        emit Deployed(
            kali,
            _token,
            _tokenId,
            _name,
            _calls,
            _daoURI,
            _govSettings
        );
    }
}
