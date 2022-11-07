// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {ERC1155TokenReceiver} from "./../../KeepToken.sol";
import {KaliExtension} from "./utils/KaliExtension.sol";
import {KeepTokenBalances} from "./utils/KeepTokenBalances.sol";
import {Multicallable} from "@solbase/src/utils/Multicallable.sol";
import {ReentrancyGuard} from "@solbase/src/utils/ReentrancyGuard.sol";

/// @notice Kali DAO core for on-chain governance.
contract Kali is ERC1155TokenReceiver, Multicallable, ReentrancyGuard {
    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event NewProposal(
        address indexed proposer,
        uint256 indexed proposal,
        ProposalType proposalType,
        bytes32 description,
        address[] accounts,
        uint256[] amounts,
        bytes[] payloads,
        uint40 creationTime,
        bool selfSponsor
    );

    event ProposalCancelled(address indexed proposer, uint256 indexed proposal);

    event ProposalSponsored(address indexed sponsor, uint256 indexed proposal);

    event VoteCast(
        address indexed voter,
        uint256 indexed proposal,
        bool approve,
        uint256 weight,
        bytes32 details
    );

    event ProposalProcessed(uint256 indexed proposal, bool passed);

    event ExtensionSet(address indexed extension, bool on);

    event URIset(string daoURI);

    event GovSettingsUpdated(
        uint120 votingPeriod,
        uint120 gracePeriod,
        uint8 quorum,
        uint8 supermajority
    );

    /// -----------------------------------------------------------------------
    /// Custom Errors
    /// -----------------------------------------------------------------------

    error LengthMismatch();

    error Initialized();

    error PeriodBounds();

    error QuorumMax();

    error SupermajorityBounds();

    error CallFail();

    error TypeBounds();

    error NotProposer();

    error Sponsored();

    error InvalidSig();

    error NotMember();

    error NotCurrentProposal();

    error AlreadyVoted();

    error NotVoteable();

    error VotingNotEnded();

    error PrevNotProcessed();

    error Overflow();

    error NotExtension();

    /// -----------------------------------------------------------------------
    /// DAO Storage/Logic
    /// -----------------------------------------------------------------------

    uint256 internal currentSponsoredProposal;

    uint256 public proposalCount;

    string public daoURI;

    uint120 public votingPeriod;

    uint120 public gracePeriod;

    uint8 public quorum; // 1-100

    uint8 public supermajority; // 1-100

    mapping(address => bool) public extensions;

    mapping(uint256 => Proposal) public proposals;

    mapping(uint256 => ProposalState) public proposalStates;

    mapping(ProposalType => VoteType) public proposalVoteTypes;

    mapping(uint256 => mapping(address => bool)) public voted;

    mapping(address => uint256) public lastYesVote;

    enum ProposalType {
        MINT, // add membership
        BURN, // revoke membership
        CALL, // call contracts
        VPERIOD, // set `votingPeriod`
        GPERIOD, // set `gracePeriod`
        QUORUM, // set `quorum`
        SUPERMAJORITY, // set `supermajority`
        TYPE, // set `VoteType` to `ProposalType`
        PAUSE, // flip membership transferability
        EXTENSION, // flip `extensions` whitelisting
        ESCAPE, // delete pending proposal in case of revert
        DOCS // amend org docs
    }

    enum VoteType {
        SIMPLE_MAJORITY,
        SIMPLE_MAJORITY_QUORUM_REQUIRED,
        SUPERMAJORITY,
        SUPERMAJORITY_QUORUM_REQUIRED
    }

    struct Proposal {
        uint256 prevProposal;
        bytes32 proposalHash;
        address proposer;
        uint40 creationTime;
        uint216 yesVotes;
        uint216 noVotes;
    }

    struct ProposalState {
        bool passed;
        bool processed;
    }

    function token() public pure returns (KeepTokenBalances tkn) {
        uint256 placeholder;

        assembly {
            placeholder := sub(
                calldatasize(),
                add(shr(240, calldataload(sub(calldatasize(), 2))), 2)
            )

            tkn := shr(0x60, calldataload(add(placeholder, 2)))
        }
    }

    function tokenId() public pure virtual returns (uint256 id) {
        uint256 placeholder;

        assembly {
            placeholder := sub(
                calldatasize(),
                add(shr(240, calldataload(sub(calldatasize(), 2))), 2)
            )

            id := calldataload(add(placeholder, 22))
        }
    }

    function name() public pure virtual returns (string memory) {
        uint256 placeholder;

        assembly {
            placeholder := sub(
                calldatasize(),
                add(shr(240, calldataload(sub(calldatasize(), 2))), 2)
            )

            placeholder := calldataload(add(placeholder, 54))
        }

        return string(abi.encodePacked(placeholder));
    }

    /// -----------------------------------------------------------------------
    /// ERC165 Logic
    /// -----------------------------------------------------------------------

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        returns (bool)
    {
        return
            // ERC165 interface ID for ERC165.
            interfaceId == this.supportsInterface.selector ||
            // ERC165 Interface ID for ERC721TokenReceiver.
            interfaceId == this.onERC721Received.selector ||
            // ERC165 Interface ID for ERC1155TokenReceiver.
            interfaceId == type(ERC1155TokenReceiver).interfaceId;
    }

    /// -----------------------------------------------------------------------
    /// ERC721 Receiver Logic
    /// -----------------------------------------------------------------------

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) public payable virtual returns (bytes4) {
        return this.onERC721Received.selector;
    }

    /// -----------------------------------------------------------------------
    /// Initialization Logic
    /// -----------------------------------------------------------------------

    function initialize(
        string calldata _daoURI,
        address[] calldata _extensions,
        bytes[] calldata _extensionsData,
        uint120[4] calldata _govSettings
    ) public payable virtual {
        if (_extensions.length != _extensionsData.length)
            revert LengthMismatch();

        if (votingPeriod != 0) revert Initialized();

        if (_govSettings[0] == 0) revert PeriodBounds();

        if (_govSettings[0] > 365 days) revert PeriodBounds();

        if (_govSettings[1] > 365 days) revert PeriodBounds();

        if (_govSettings[2] > 100) revert QuorumMax();

        if (_govSettings[3] <= 51) revert SupermajorityBounds();

        if (_govSettings[3] > 100) revert SupermajorityBounds();

        if (_extensions.length != 0) {
            for (uint256 i; i < _extensions.length; ) {
                extensions[_extensions[i]] = true;

                if (_extensionsData[i].length > 9) {
                    (bool success, ) = _extensions[i].call(_extensionsData[i]);

                    if (!success) revert CallFail();
                }

                // An array can't have a total length
                // larger than the max uint256 value.
                unchecked {
                    ++i;
                }
            }
        }

        daoURI = _daoURI;

        votingPeriod = uint120(_govSettings[0]);

        gracePeriod = uint120(_govSettings[1]);

        quorum = uint8(_govSettings[2]);

        supermajority = uint8(_govSettings[3]);
    }

    /// -----------------------------------------------------------------------
    /// EIP-712 Storage/Logic
    /// -----------------------------------------------------------------------

    function DOMAIN_SEPARATOR() public view virtual returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    // `keccak256(
                    //     "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                    // )`
                    0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f,
                    // `keccak256(bytes("Kali"))`
                    0xd321353274be6f42cf7b550879ff1a1c924e1e8f469054b23c7354e7f1737c64,
                    // `keccak256("1")`
                    0xc89efdaa54c0f20c7adf612882df0950f5a951637e0307cdcb4c672f298b8bc6,
                    block.chainid,
                    address(this)
                )
            );
    }

    /// -----------------------------------------------------------------------
    /// Proposal Logic
    /// -----------------------------------------------------------------------

    function propose(
        ProposalType proposalType,
        bytes32 description,
        address[] calldata accounts, // Member(s) being added/kicked; account(s) receiving payload.
        uint256[] calldata amounts, // Value(s) to be minted/burned/spent; gov setting [0].
        bytes[] calldata payloads // Data for CALL proposals.
    ) public payable virtual returns (uint256 proposal) {
        if (accounts.length != amounts.length) revert LengthMismatch();

        if (amounts.length != payloads.length) revert LengthMismatch();

        if (proposalType == ProposalType.VPERIOD)
            if (amounts[0] == 0 || amounts[0] > 365 days) revert PeriodBounds();

        if (proposalType == ProposalType.GPERIOD)
            if (amounts[0] > 365 days) revert PeriodBounds();

        if (proposalType == ProposalType.QUORUM)
            if (amounts[0] > 100) revert QuorumMax();

        if (proposalType == ProposalType.SUPERMAJORITY)
            if (amounts[0] <= 51 || amounts[0] > 100)
                revert SupermajorityBounds();

        if (proposalType == ProposalType.TYPE)
            if (amounts[0] > 11 || amounts[1] > 3 || amounts.length != 2)
                revert TypeBounds();

        bool selfSponsor;

        // If member or extension is making proposal, include sponsorship.
        if (
            token().balanceOf(msg.sender, tokenId()) != 0 ||
            extensions[msg.sender]
        ) selfSponsor = true;

        // Cannot realistically overflow on human timescales.
        unchecked {
            proposal = ++proposalCount;
        }

        bytes32 proposalHash = keccak256(
            abi.encode(proposalType, description, accounts, amounts, payloads)
        );

        uint40 creationTime = selfSponsor ? _safeCastTo40(block.timestamp) : 0;

        proposals[proposal] = Proposal({
            prevProposal: selfSponsor ? currentSponsoredProposal : 0,
            proposalHash: proposalHash,
            proposer: msg.sender,
            creationTime: creationTime,
            yesVotes: 0,
            noVotes: 0
        });

        if (selfSponsor) currentSponsoredProposal = proposal;

        emit NewProposal(
            msg.sender,
            proposal,
            proposalType,
            description,
            accounts,
            amounts,
            payloads,
            creationTime,
            selfSponsor
        );
    }

    function cancelProposal(uint256 proposal) public payable virtual {
        Proposal storage prop = proposals[proposal];

        if (msg.sender != prop.proposer)
            if (!extensions[msg.sender]) revert NotProposer();

        if (prop.creationTime != 0) revert Sponsored();

        delete proposals[proposal];

        emit ProposalCancelled(msg.sender, proposal);
    }

    function sponsorProposal(uint256 proposal) public payable virtual {
        Proposal storage prop = proposals[proposal];

        if (token().balanceOf(msg.sender, tokenId()) == 0)
            if (!extensions[msg.sender]) revert NotMember();

        if (prop.proposer == address(0)) revert NotCurrentProposal();

        if (prop.creationTime != 0) revert Sponsored();

        prop.prevProposal = currentSponsoredProposal;

        currentSponsoredProposal = proposal;

        prop.creationTime = _safeCastTo40(block.timestamp);

        emit ProposalSponsored(msg.sender, proposal);
    }

    function vote(
        uint256 proposal,
        bool approve,
        bytes32 details
    ) public payable virtual nonReentrant {
        _vote(msg.sender, proposal, approve, details);
    }

    function voteBySig(
        uint256 proposal,
        bool approve,
        bytes32 details,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public payable virtual nonReentrant {
        address recoveredAddress = ecrecover(
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            keccak256(
                                "SignVote(uint256 proposal,bool approve,bytes32 details)"
                            ),
                            proposal,
                            approve,
                            details
                        )
                    )
                )
            ),
            v,
            r,
            s
        );

        if (recoveredAddress == address(0)) revert InvalidSig();

        _vote(recoveredAddress, proposal, approve, details);
    }

    function _vote(
        address signer,
        uint256 proposal,
        bool approve,
        bytes32 details
    ) internal virtual {
        Proposal storage prop = proposals[proposal];

        if (voted[proposal][signer]) revert AlreadyVoted();

        voted[proposal][signer] = true;

        // This is safe from overflow because `votingPeriod`
        // is capped so it will not combine with unix time
        // to exceed the max uint256 value.
        unchecked {
            if (block.timestamp > prop.creationTime + votingPeriod)
                revert NotVoteable();
        }

        uint216 weight = uint216(
            token().getPriorVotes(signer, tokenId(), prop.creationTime)
        );

        // This is safe from overflow because `yesVotes`
        // and `noVotes` are capped by `totalSupply`
        // which is checked for overflow in `token` contract.
        unchecked {
            if (approve) {
                prop.yesVotes += weight;

                lastYesVote[signer] = proposal;
            } else {
                prop.noVotes += weight;
            }
        }

        emit VoteCast(signer, proposal, approve, weight, details);
    }

    function processProposal(
        uint256 proposal,
        ProposalType proposalType,
        bytes32 description,
        address[] calldata accounts,
        uint256[] calldata amounts,
        bytes[] calldata payloads
    )
        public
        payable
        virtual
        nonReentrant
        returns (bool passed, bytes[] memory results)
    {
        Proposal storage prop = proposals[proposal];

        delete proposals[proposal];

        {
            // Scope to avoid stack too deep error.
            VoteType voteType = proposalVoteTypes[proposalType];

            if (prop.creationTime == 0) revert NotCurrentProposal();

            bytes32 proposalHash = keccak256(
                abi.encode(
                    proposalType,
                    description,
                    accounts,
                    amounts,
                    payloads
                )
            );

            if (proposalHash != prop.proposalHash) revert NotCurrentProposal();

            // Skip previous proposal processing requirement
            // in case of escape hatch.
            if (proposalType != ProposalType.ESCAPE)
                if (proposals[prop.prevProposal].creationTime != 0)
                    revert PrevNotProcessed();

            passed = _countVotes(voteType, prop.yesVotes, prop.noVotes);
        } // End scope.

        // This is safe from overflow because `votingPeriod`
        // and `gracePeriod` are capped so they will not combine
        // with unix time to exceed the max uint256 value.
        if (!passed || gracePeriod != 0) {
            if (
                block.timestamp <=
                prop.creationTime + votingPeriod + gracePeriod
            ) revert VotingNotEnded();
        }

        if (passed) {
            // An array can't have a total length
            // larger than the max uint256 value.
            unchecked {
                if (proposalType == ProposalType.MINT) {
                    for (uint256 i; i < accounts.length; ++i) {
                        results = new bytes[](accounts.length);

                        (, bytes memory result) = address(token()).call(
                            abi.encodeWithSelector(
                                0x731133e9, // `mint()`
                                accounts[i],
                                tokenId(),
                                amounts[i],
                                payloads[i]
                            )
                        );

                        results[i] = result;
                    }
                } else if (proposalType == ProposalType.BURN) {
                    for (uint256 i; i < accounts.length; ++i) {
                        results = new bytes[](accounts.length);

                        (, bytes memory result) = address(token()).call(
                            abi.encodeWithSelector(
                                0xf5298aca, // `burn()`
                                accounts[i],
                                tokenId(),
                                amounts[i]
                            )
                        );

                        results[i] = result;
                    }
                } else if (proposalType == ProposalType.CALL) {
                    for (uint256 i; i < accounts.length; ++i) {
                        results = new bytes[](accounts.length);

                        (, bytes memory result) = accounts[i].call{
                            value: amounts[i]
                        }(payloads[i]);

                        results[i] = result;
                    }
                } else if (proposalType == ProposalType.VPERIOD) {
                    votingPeriod = uint120(amounts[0]);
                } else if (proposalType == ProposalType.GPERIOD) {
                    gracePeriod = uint120(amounts[0]);
                } else if (proposalType == ProposalType.QUORUM) {
                    quorum = uint8(amounts[0]);
                } else if (proposalType == ProposalType.SUPERMAJORITY) {
                    supermajority = uint8(amounts[0]);
                } else if (proposalType == ProposalType.TYPE) {
                    proposalVoteTypes[ProposalType(amounts[0])] = VoteType(
                        amounts[1]
                    );
                } else if (proposalType == ProposalType.PAUSE) {
                    results = new bytes[](1);

                    (, bytes memory result) = address(token()).call(
                        abi.encodeWithSelector(
                            0x7140d960, // `setTransferability()`
                            tokenId(),
                            !token().transferable(tokenId())
                        )
                    );

                    results[0] = result;
                } else if (proposalType == ProposalType.EXTENSION) {
                    for (uint256 i; i < accounts.length; ++i) {
                        if (amounts[i] != 0)
                            extensions[accounts[i]] = !extensions[accounts[i]];

                        if (payloads[i].length > 9)
                            KaliExtension(accounts[i]).setExtension(
                                payloads[i]
                            );
                    }
                } else if (proposalType == ProposalType.ESCAPE) {
                    delete proposals[amounts[0]];
                } else if (proposalType == ProposalType.DOCS) {
                    daoURI = string(abi.encodePacked(description));
                }

                proposalStates[proposal].passed = true;
            }
        }

        proposalStates[proposal].processed = true;

        emit ProposalProcessed(proposal, passed);
    }

    function _countVotes(
        VoteType voteType,
        uint256 yesVotes,
        uint256 noVotes
    ) internal view virtual returns (bool passed) {
        // Fail proposal if no participation.
        if (yesVotes == 0)
            if (noVotes == 0) return false;

        // Rule out any failed quorums.
        if (
            voteType == VoteType.SIMPLE_MAJORITY_QUORUM_REQUIRED ||
            voteType == VoteType.SUPERMAJORITY_QUORUM_REQUIRED
        ) {
            // This is safe from overflow because `yesVotes`
            // and `noVotes` supply are checked
            // in `token` contract.
            unchecked {
                if (
                    (yesVotes + noVotes) <
                    ((token().totalSupply(tokenId()) * quorum) / 100)
                ) return false;
            }
        }

        // Simple majority check.
        if (
            voteType == VoteType.SIMPLE_MAJORITY ||
            voteType == VoteType.SIMPLE_MAJORITY_QUORUM_REQUIRED
        ) {
            if (yesVotes > noVotes) return true;
            // Supermajority check.
        } else {
            // Example: 7 yes, 2 no, supermajority = 66
            // ((7+2) * 66) / 100 = 5.94; 7 yes will pass.
            // This is safe from overflow because `yesVotes`
            // and `noVotes` supply are checked
            // in `token` contract.
            unchecked {
                if (yesVotes >= ((yesVotes + noVotes) * supermajority) / 100)
                    return true;
            }
        }
    }

    /// -----------------------------------------------------------------------
    /// Safecast Logic
    /// -----------------------------------------------------------------------

    function _safeCastTo40(uint256 x) internal pure virtual returns (uint40) {
        if (x >= (1 << 40)) revert Overflow();

        return uint40(x);
    }

    /// -----------------------------------------------------------------------
    /// Extension Logic
    /// -----------------------------------------------------------------------

    modifier onlyExtension() {
        if (!extensions[msg.sender]) revert NotExtension();

        _;
    }

    function relay(
        address account,
        uint256 amount,
        bytes calldata payload
    )
        public
        payable
        virtual
        onlyExtension
        nonReentrant
        returns (bool success, bytes memory result)
    {
        (success, result) = account.call{value: amount}(payload);

        if (!success) revert CallFail();
    }

    function setExtension(address extension, bool on) public payable virtual {
        if (!extensions[msg.sender])
            if (msg.sender != address(this)) revert NotExtension();

        extensions[extension] = on;

        emit ExtensionSet(extension, on);
    }

    function setURI(string calldata _daoURI)
        public
        payable
        virtual
        onlyExtension
    {
        daoURI = _daoURI;

        emit URIset(_daoURI);
    }

    function updateGovSettings(
        uint120 _votingPeriod,
        uint120 _gracePeriod,
        uint8 _quorum,
        uint8 _supermajority
    ) public payable virtual onlyExtension {
        if (_votingPeriod != 0)
            if (_votingPeriod <= 365 days) votingPeriod = _votingPeriod;

        if (_gracePeriod <= 365 days) gracePeriod = _gracePeriod;

        quorum = _quorum;

        if (_supermajority > 51)
            if (_supermajority <= 100) supermajority = _supermajority;

        emit GovSettingsUpdated(
            _votingPeriod,
            _gracePeriod,
            _quorum,
            _supermajority
        );
    }
}
