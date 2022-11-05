// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {KeepTokenBalances, Multicallable, Kali} from "./Kali.sol";
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
        bytes32 name,
        string daoURI,
        address[] extensions,
        bytes[] extensionsData,
        uint120[5] govSettings
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

    function determineKali(KeepTokenBalances token, bytes32 name)
        public
        view
        virtual
        returns (address)
    {
        return
            address(kaliTemplate).predictDeterministicAddress(
                abi.encodePacked(token, name),
                name,
                address(this)
            );
    }

    function deployKali(
        KeepTokenBalances _token,
        bytes32 _name, // create2 salt.
        string calldata _daoURI,
        address[] calldata _extensions,
        bytes[] calldata _extensionsData,
        uint120[5] calldata _govSettings
    ) public payable virtual {
        Kali kali = Kali(
            address(kaliTemplate).cloneDeterministic(
                abi.encodePacked(_token, _name),
                _name
            )
        );

        kali.initialize{value: msg.value}(
            _daoURI,
            _extensions,
            _extensionsData,
            _govSettings
        );

        emit Deployed(
            kali,
            _token,
            _name,
            _daoURI,
            _extensions,
            _extensionsData,
            _govSettings
        );
    }
}
