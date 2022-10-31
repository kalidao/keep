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
        uint256 creationTime,
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

    event ProposalProcessed(uint256 indexed proposal, bool didProposalPass);

    event ExtensionSet(address indexed extension, bool set);

    event URIset(string daoURI);

    event GovSettingsUpdated(
        uint256 votingPeriod,
        uint256 gracePeriod,
        uint256 quorum,
        uint256 supermajority
    );

    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    error LengthMismatch();

    error Initialized();

    error PeriodBounds();

    error QuorumMax();

    error SupermajorityBounds();

    error InitCallFail();

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

    KeepTokenBalances public token;

    uint16 public votingPeriod;

    uint16 public gracePeriod;

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
        uint32 creationTime;
        uint96 yesVotes;
        uint96 noVotes;
    }

    struct ProposalState {
        bool passed;
        bool processed;
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
        KeepTokenBalances _token,
        string calldata _daoURI,
        address[] calldata _extensions,
        bytes[] calldata _extensionsData,
        uint256[5] calldata _govSettings
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
            // cannot realistically overflow on human timescales
            unchecked {
                for (uint256 i; i < _extensions.length; i++) {
                    extensions[_extensions[i]] = true;

                    if (_extensionsData[i].length > 9) {
                        (bool success, ) = _extensions[i].call(
                            _extensionsData[i]
                        );

                        if (!success) revert InitCallFail();
                    }
                }
            }
        }

        token = _token;

        daoURI = _daoURI;

        votingPeriod = uint16(_govSettings[0]);

        gracePeriod = uint16(_govSettings[1]);

        quorum = uint8(_govSettings[2]);

        supermajority = uint8(_govSettings[3]);

        _initialDomainSeparator = _computeDomainSeparator();
    }

    /// -----------------------------------------------------------------------
    /// EIP-712 Storage/Logic
    /// -----------------------------------------------------------------------

    bytes32 internal _initialDomainSeparator;

    function DOMAIN_SEPARATOR() public view virtual returns (bytes32) {
        return
            block.chainid == _initialChainId()
                ? _initialDomainSeparator
                : _computeDomainSeparator();
    }

    function name() public pure virtual returns (string memory) {
        return string(abi.encodePacked(_computeArgUint(2)));
    }

    function _initialChainId() internal pure virtual returns (uint256) {
        return _computeArgUint(7);
    }

    function _computeDomainSeparator() internal view virtual returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    keccak256(
                        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                    ),
                    keccak256(bytes("Kali")),
                    keccak256("1"),
                    block.chainid,
                    address(this)
                )
            );
    }

    function _computeArgUint(uint256 argOffset)
        internal
        pure
        virtual
        returns (uint256 arg)
    {
        uint256 offset;

        assembly {
            offset := sub(
                calldatasize(),
                add(shr(240, calldataload(sub(calldatasize(), 2))), 2)
            )

            arg := calldataload(add(offset, argOffset))
        }
    }

    /// -----------------------------------------------------------------------
    /// Proposal Logic
    /// -----------------------------------------------------------------------

    function propose(
        ProposalType proposalType,
        bytes32 description,
        address[] calldata accounts, // member(s) being added/kicked; account(s) receiving payload
        uint256[] calldata amounts, // value(s) to be minted/burned/spent; gov setting [0]
        bytes[] calldata payloads // data for CALL proposals
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

        // if member or extension is making proposal, include sponsorship
        if (token.balanceOf(msg.sender, 0) != 0 || extensions[msg.sender])
            selfSponsor = true;

        // cannot realistically overflow on human timescales
        unchecked {
            proposal = ++proposalCount;
        }

        bytes32 proposalHash = keccak256(
            abi.encode(proposalType, description, accounts, amounts, payloads)
        );

        uint32 creationTime = selfSponsor ? _safeCastTo32(block.timestamp) : 0;

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

        if (msg.sender != prop.proposer && !extensions[msg.sender])
            revert NotProposer();

        if (prop.creationTime != 0) revert Sponsored();

        delete proposals[proposal];

        emit ProposalCancelled(msg.sender, proposal);
    }

    function sponsorProposal(uint256 proposal) public payable virtual {
        Proposal storage prop = proposals[proposal];

        if (token.balanceOf(msg.sender, 0) == 0 && !extensions[msg.sender])
            revert NotMember();

        if (prop.proposer == address(0)) revert NotCurrentProposal();

        if (prop.creationTime != 0) revert Sponsored();

        prop.prevProposal = currentSponsoredProposal;

        currentSponsoredProposal = proposal;

        prop.creationTime = _safeCastTo32(block.timestamp);

        emit ProposalSponsored(msg.sender, proposal);
    }

    function vote(
        uint256 proposal,
        bool approve,
        bytes32 details
    ) public payable virtual {
        _vote(msg.sender, proposal, approve, details);
    }

    function voteBySig(
        uint256 proposal,
        bool approve,
        bytes32 details,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public payable virtual {
        address recoveredAddress = ecrecover(
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            keccak256(
                                "SignVote(uint256 proposal,bool approve)"
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

        // this is safe from overflow because `votingPeriod` is capped so it will not combine
        // with unix time to exceed the max uint256 value
        unchecked {
            if (block.timestamp > prop.creationTime + votingPeriod)
                revert NotVoteable();
        }

        uint256 weight = token.getPriorVotes(signer, 0, prop.creationTime);

        // this is safe from overflow because `yesVotes` and `noVotes` are capped by `totalSupply`
        // which is checked for overflow in `KaliDAOtoken` contract
        unchecked {
            if (approve) {
                prop.yesVotes += uint96(weight);

                lastYesVote[signer] = proposal;
            } else {
                prop.noVotes += uint96(weight);
            }
        }

        voted[proposal][signer] = true;

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
        returns (bool didProposalPass, bytes[] memory results)
    {
        Proposal storage prop = proposals[proposal];

        {
            // scope to avoid stack too deep error
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

            // skip previous proposal processing requirement in case of escape hatch
            if (proposalType != ProposalType.ESCAPE)
                if (proposals[prop.prevProposal].creationTime != 0)
                    revert PrevNotProcessed();

            didProposalPass = _countVotes(
                voteType,
                prop.yesVotes,
                prop.noVotes
            );
        } // end scope

        // this is safe from overflow because `votingPeriod` and `gracePeriod` are capped so they will not combine
        // with unix time to exceed the max uint256 value
        unchecked {
            if (!didProposalPass && gracePeriod != 0) {
                if (
                    block.timestamp <=
                    prop.creationTime +
                        (votingPeriod -
                            (block.timestamp -
                                (prop.creationTime + votingPeriod))) +
                        gracePeriod
                ) revert VotingNotEnded();
            }
        }

        if (didProposalPass) {
            // cannot realistically overflow on human timescales
            unchecked {
                if (proposalType == ProposalType.MINT) {
                    for (uint256 i; i < accounts.length; i++) {
                        results = new bytes[](accounts.length);

                        (, bytes memory result) = address(token).call(
                            abi.encodeWithSelector(
                                0x731133e9,
                                accounts[i],
                                0,
                                amounts[i],
                                payloads[i]
                            )
                        );

                        results[i] = result;
                    }
                } else if (proposalType == ProposalType.BURN) {
                    for (uint256 i; i < accounts.length; i++) {
                        results = new bytes[](accounts.length);

                        (, bytes memory result) = address(token).call(
                            abi.encodeWithSelector(
                                0xf5298aca,
                                accounts[i],
                                0,
                                amounts[i]
                            )
                        );

                        results[i] = result;
                    }
                } else if (proposalType == ProposalType.CALL) {
                    for (uint256 i; i < accounts.length; i++) {
                        results = new bytes[](accounts.length);

                        (, bytes memory result) = accounts[i].call{
                            value: amounts[i]
                        }(payloads[i]);

                        results[i] = result;
                    }
                } else if (proposalType == ProposalType.VPERIOD) {
                    if (amounts[0] != 0) votingPeriod = uint16(amounts[0]);
                } else if (proposalType == ProposalType.GPERIOD) {
                    if (amounts[0] != 0) gracePeriod = uint16(amounts[0]);
                } else if (proposalType == ProposalType.QUORUM) {
                    if (amounts[0] != 0) quorum = uint8(amounts[0]);
                } else if (proposalType == ProposalType.SUPERMAJORITY) {
                    if (amounts[0] != 0) supermajority = uint8(amounts[0]);
                } else if (proposalType == ProposalType.TYPE) {
                    proposalVoteTypes[ProposalType(amounts[0])] = VoteType(
                        amounts[1]
                    );
                } else if (proposalType == ProposalType.PAUSE) {
                    (, bytes memory result) = address(token).call(
                        abi.encodeWithSelector(
                            0x7140d960,
                            0,
                            !token.transferable(0)
                        )
                    );

                    results[0] = result;
                } else if (proposalType == ProposalType.EXTENSION) {
                    for (uint256 i; i < accounts.length; i++) {
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

        delete proposals[proposal];

        proposalStates[proposal].processed = true;

        emit ProposalProcessed(proposal, didProposalPass);
    }

    function _countVotes(
        VoteType voteType,
        uint96 yesVotes,
        uint96 noVotes
    ) internal view virtual returns (bool didProposalPass) {
        // fail proposal if no participation
        if (yesVotes == 0 && noVotes == 0) return false;

        // rule out any failed quorums
        if (
            voteType == VoteType.SIMPLE_MAJORITY_QUORUM_REQUIRED ||
            voteType == VoteType.SUPERMAJORITY_QUORUM_REQUIRED
        ) {
            // this is safe from overflow because `yesVotes` and `noVotes`
            // supply are checked in `KaliDAOtoken` contract
            unchecked {
                if (
                    (yesVotes + noVotes) <
                    ((token.totalSupply(0) * quorum) / 100)
                ) return false;
            }
        }

        // simple majority check
        if (
            voteType == VoteType.SIMPLE_MAJORITY ||
            voteType == VoteType.SIMPLE_MAJORITY_QUORUM_REQUIRED
        ) {
            if (yesVotes > noVotes) return true;
            // supermajority check
        } else {
            // example: 7 yes, 2 no, supermajority = 66
            // ((7+2) * 66) / 100 = 5.94; 7 yes will pass ~~
            // this is safe from overflow because `yesVotes` and `noVotes`
            // supply are checked in `KaliDAOtoken` contract
            unchecked {
                if (yesVotes >= ((yesVotes + noVotes) * supermajority) / 100)
                    return true;
            }
        }
    }

    /// -----------------------------------------------------------------------
    /// Safecast Logic
    /// -----------------------------------------------------------------------

    function _safeCastTo32(uint256 x) internal pure virtual returns (uint32) {
        if (x >= (1 << 32)) revert Overflow();

        return uint32(x);
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
        returns (bool success, bytes memory result)
    {
        (success, result) = account.call{value: amount}(payload);
    }

    function setExtension(address extension, bool set) public payable virtual {
        if (!extensions[msg.sender] || msg.sender != address(this))
            revert NotExtension();

        extensions[extension] = set;

        emit ExtensionSet(extension, set);
    }

    function setURI(string calldata daoURI_)
        public
        payable
        virtual
        onlyExtension
    {
        daoURI = daoURI_;

        emit URIset(daoURI_);
    }

    function updateGovSettings(
        uint256 _votingPeriod,
        uint256 _gracePeriod,
        uint256 _quorum,
        uint256 _supermajority
    ) public payable virtual onlyExtension {
        if (_votingPeriod != 0) votingPeriod = uint16(_votingPeriod);

        if (_gracePeriod != 0) gracePeriod = uint16(_gracePeriod);

        if (_quorum != 0) quorum = uint8(_quorum);

        if (_supermajority != 0) supermajority = uint8(_supermajority);

        emit GovSettingsUpdated(
            _votingPeriod,
            _gracePeriod,
            _quorum,
            _supermajority
        );
    }
}
