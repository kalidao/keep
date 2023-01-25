// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {KaliExtension} from "./utils/KaliExtension.sol";
import {Multicallable} from "../../utils/Multicallable.sol";
import {ReentrancyGuard} from "../utils/ReentrancyGuard.sol";
import {KeepTokenManager} from "./utils/KeepTokenManager.sol";
import {ERC1155TokenReceiver, Operation, Call, Signature} from "./../../Keep.sol";

/// @title Kali
/// @notice Kali DAO core for on-chain governance.
/// @author z0r0z.eth

enum ProposalType {
    MINT, // Add to membership.
    BURN, // Revoke membership.
    CALL, // Call to external code.
    VPERIOD, // Set `votingPeriod`.
    GPERIOD, // Set `gracePeriod`.
    QUORUM, // Set `quorum`.
    SUPERMAJORITY, // Set `supermajority`.
    TYPE, // Set `VoteType` `ProposalType`.
    PAUSE, // Flip membership transferability.
    EXTENSION, // Flip `extensions` permission.
    ESCAPE, // Delete pending proposal in queue.
    URI // Amend root documentation for the DAO.
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

contract Kali is ERC1155TokenReceiver, Multicallable, ReentrancyGuard {
    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event NewProposal(
        address indexed proposer,
        uint256 indexed proposal,
        Call[] calls,
        ProposalType setting,
        string details,
        uint256 creationTime,
        bool sponsored
    );

    event ProposalCancelled(address indexed proposer, uint256 indexed proposal);

    event ProposalSponsored(address indexed sponsor, uint256 indexed proposal);

    event VoteCast(
        address indexed voter,
        uint256 indexed proposal,
        bool approve,
        uint256 weight,
        string details
    );

    event ProposalProcessed(uint256 indexed proposal, bool passed);

    event ExtensionSet(address indexed extension, bool on);

    event URIset(string daoURI);

    event GovSettingsUpdated(
        uint256 votingPeriod,
        uint256 gracePeriod,
        uint256 quorum,
        uint256 supermajority,
        uint256[2] typeSetting
    );

    event Executed(
        Operation op,
        address to,
        uint256 value,
        bytes data,
        bool success
    );

    /// -----------------------------------------------------------------------
    /// Custom Errors
    /// -----------------------------------------------------------------------

    error Initialized();

    error PeriodBounds();

    error QuorumMax();

    error SupermajorityBounds();

    error TypeBounds();

    error Unauthorized();

    error Sponsored();

    error InvalidProposal();

    error AlreadyVoted();

    error InvalidHash();

    error PrevNotProcessed();

    error VotingNotEnded();

    error InvalidSig();

    error Overflow();

    /// -----------------------------------------------------------------------
    /// DAO Storage/Logic
    /// -----------------------------------------------------------------------

    bytes32 internal constant MALLEABILITY_THRESHOLD =
        0x7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0;

    uint256 internal currentSponsoredProposal;

    uint256 public proposalCount;

    string public daoURI;

    uint120 public votingPeriod;

    uint120 public gracePeriod;

    uint8 public quorum; // 1-100.

    uint8 public supermajority; // 1-100.

    mapping(address => bool) public extensions;

    mapping(uint256 => Proposal) public proposals;

    mapping(uint256 => ProposalState) public proposalStates;

    mapping(ProposalType => VoteType) public proposalVoteTypes;

    mapping(uint256 => mapping(address => bool)) public voted;

    mapping(address => uint256) public lastYesVote;

    function token() public pure virtual returns (KeepTokenManager tkn) {
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
        return _fetchImmutable(22);
    }

    function name() public pure virtual returns (string memory) {
        return string(abi.encodePacked(_fetchImmutable(54)));
    }

    function _fetchImmutable(
        uint256 place
    ) internal pure virtual returns (uint256 ref) {
        uint256 placeholder;

        assembly {
            placeholder := sub(
                calldatasize(),
                add(shr(240, calldataload(sub(calldatasize(), 2))), 2)
            )

            ref := calldataload(add(placeholder, place))
        }
    }

    /// -----------------------------------------------------------------------
    /// ERC165 Logic
    /// -----------------------------------------------------------------------

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual returns (bool) {
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

    constructor() payable {
        // Deploy as singleton.
        votingPeriod = 1;
    }

    function initialize(
        Call[] calldata _calls,
        string calldata _daoURI,
        uint120[4] calldata _govSettings
    ) public payable virtual {
        if (votingPeriod != 0) revert Initialized();

        if (_govSettings[0] == 0) revert PeriodBounds();

        if (_govSettings[0] > 365 days) revert PeriodBounds();

        if (_govSettings[1] > 365 days) revert PeriodBounds();

        if (_govSettings[2] > 100) revert QuorumMax();

        if (_govSettings[3] <= 51) revert SupermajorityBounds();

        if (_govSettings[3] > 100) revert SupermajorityBounds();

        if (_calls.length != 0) {
            for (uint256 i; i < _calls.length; ) {
                extensions[_calls[i].to] = true;

                if (_calls[i].data.length > 3)
                    _execute(
                        _calls[i].op,
                        _calls[i].to,
                        _calls[i].value,
                        _calls[i].data
                    );

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
    /// EIP-712 Logic
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
        Call[] calldata calls,
        ProposalType setting,
        string calldata details
    ) public payable virtual returns (uint256 proposal, uint40 creationTime) {
        if (setting != ProposalType.MINT)
            if (setting != ProposalType.BURN)
                if (setting != ProposalType.CALL)
                    if (setting == ProposalType.VPERIOD)
                        if (calls[0].value == 0 || calls[0].value > 365 days)
                            revert PeriodBounds();
                        else if (setting == ProposalType.GPERIOD)
                            if (calls[0].value > 365 days)
                                revert PeriodBounds();
                            else if (setting == ProposalType.QUORUM)
                                if (calls[0].value > 100) revert QuorumMax();
                                else if (setting == ProposalType.SUPERMAJORITY)
                                    if (
                                        calls[0].value <= 51 ||
                                        calls[0].value > 100
                                    ) revert SupermajorityBounds();
                                    else if (setting == ProposalType.TYPE)
                                        if (
                                            calls[0].value > 11 ||
                                            calls[1].value > 3
                                        ) revert TypeBounds();
        bool sponsored;

        // If member or extension is making proposal, include sponsorship.
        if (
            token().balanceOf(msg.sender, tokenId()) != 0 ||
            extensions[msg.sender]
        ) sponsored = true;

        // Proposal count cannot realistically overflow on human timescales.
        unchecked {
            proposals[proposal = ++proposalCount] = Proposal({
                prevProposal: sponsored ? currentSponsoredProposal : 0,
                proposalHash: keccak256(abi.encode(calls, setting, details)),
                proposer: msg.sender,
                creationTime: creationTime = sponsored
                    ? _safeCastTo40(block.timestamp)
                    : 0,
                yesVotes: 0,
                noVotes: 0
            });
        }

        if (sponsored) currentSponsoredProposal = proposal;

        emit NewProposal(
            msg.sender,
            proposal,
            calls,
            setting,
            details,
            creationTime,
            sponsored
        );
    }

    function cancelProposal(uint256 proposal) public payable virtual {
        Proposal storage prop = proposals[proposal];

        if (msg.sender != prop.proposer)
            if (!extensions[msg.sender]) revert Unauthorized();

        if (prop.creationTime != 0) revert Sponsored();

        delete proposals[proposal];

        emit ProposalCancelled(msg.sender, proposal);
    }

    function sponsorProposal(uint256 proposal) public payable virtual {
        Proposal storage prop = proposals[proposal];

        if (token().balanceOf(msg.sender, tokenId()) == 0)
            if (!extensions[msg.sender]) revert Unauthorized();

        if (prop.proposer == address(0)) revert InvalidProposal();

        if (prop.creationTime != 0) revert Sponsored();

        prop.prevProposal = currentSponsoredProposal;

        currentSponsoredProposal = proposal;

        prop.creationTime = _safeCastTo40(block.timestamp);

        emit ProposalSponsored(msg.sender, proposal);
    }

    /// -----------------------------------------------------------------------
    /// Voting Logic
    /// -----------------------------------------------------------------------

    function vote(
        uint256 proposal,
        bool approve,
        string calldata details
    ) public payable virtual {
        _vote(msg.sender, proposal, approve, details);
    }

    function voteBySig(
        uint256 proposal,
        bool approve,
        string calldata details,
        Signature calldata sig
    ) public payable virtual {
        bytes32 hash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        keccak256(
                            "SignVote(uint256 proposal,bool approve,string details)"
                        ),
                        proposal,
                        approve,
                        details
                    )
                )
            )
        );

        // Check signature recovery.
        _recoverSig(hash, sig.user, sig.v, sig.r, sig.s);

        _vote(sig.user, proposal, approve, details);
    }

    function _vote(
        address user,
        uint256 proposal,
        bool approve,
        string calldata details
    ) internal virtual {
        Proposal storage prop = proposals[proposal];

        if (voted[proposal][user]) revert AlreadyVoted();

        voted[proposal][user] = true;

        // This is safe from overflow because `votingPeriod`
        // is capped so it will not combine with unix time
        // to exceed the max uint256 value.
        unchecked {
            if (block.timestamp > prop.creationTime + votingPeriod)
                revert InvalidProposal();
        }

        uint216 weight = uint216(
            token().getPriorVotes(user, tokenId(), prop.creationTime)
        );

        // This is safe from overflow because `yesVotes`
        // and `noVotes` are capped by `totalSupply`
        // which is checked for overflow in `token` contract.
        unchecked {
            if (approve) {
                prop.yesVotes += weight;

                lastYesVote[user] = proposal;
            } else {
                prop.noVotes += weight;
            }
        }

        emit VoteCast(user, proposal, approve, weight, details);
    }

    /// -----------------------------------------------------------------------
    /// Processing Logic
    /// -----------------------------------------------------------------------

    function processProposal(
        uint256 proposal,
        Call[] calldata calls,
        ProposalType setting,
        string calldata details
    ) public payable virtual nonReentrant returns (bool passed) {
        Proposal storage prop = proposals[proposal];

        if (prop.creationTime == 0) revert InvalidProposal();

        if (keccak256(abi.encode(calls, setting, details)) != prop.proposalHash)
            revert InvalidHash();

        // Skip previous proposal processing requirement
        // in case of escape hatch.
        if (setting != ProposalType.ESCAPE)
            if (proposals[prop.prevProposal].creationTime != 0)
                revert PrevNotProcessed();

        passed = _countVotes(
            proposalVoteTypes[setting],
            prop.yesVotes,
            prop.noVotes
        );

        // If quorum and approval threshold are met,
        // skip voting period for fast processing.
        // If a grace period has been set,
        // or if quorum is set to nothing,
        // maintain voting period check.
        if (!passed || gracePeriod != 0 || quorum == 0) {
            // This is safe from overflow because `votingPeriod`
            // and `gracePeriod` are capped so they will not combine
            // with unix time to exceed the max uint256 value.
            unchecked {
                if (
                    block.timestamp <=
                    prop.creationTime + votingPeriod + gracePeriod
                ) revert VotingNotEnded();
            }
        }

        if (passed) {
            // An array can't have a total length
            // larger than the max uint256 value.
            unchecked {
                if (setting == ProposalType.MINT) {
                    for (uint256 i; i < calls.length; ++i) {
                        token().mint(
                            calls[i].to,
                            tokenId(),
                            calls[i].value,
                            calls[i].data
                        );
                    }
                } else if (setting == ProposalType.BURN) {
                    for (uint256 i; i < calls.length; ++i) {
                        token().burn(calls[i].to, tokenId(), calls[i].value);
                    }
                } else if (setting == ProposalType.CALL) {
                    for (uint256 i; i < calls.length; ++i) {
                        _execute(
                            calls[i].op,
                            calls[i].to,
                            calls[i].value,
                            calls[i].data
                        );
                    }
                } else if (setting == ProposalType.VPERIOD) {
                    votingPeriod = uint120(calls[0].value);
                } else if (setting == ProposalType.GPERIOD) {
                    gracePeriod = uint120(calls[0].value);
                } else if (setting == ProposalType.QUORUM) {
                    quorum = uint8(calls[0].value);
                } else if (setting == ProposalType.SUPERMAJORITY) {
                    supermajority = uint8(calls[0].value);
                } else if (setting == ProposalType.TYPE) {
                    proposalVoteTypes[ProposalType(calls[0].value)] = VoteType(
                        calls[1].value
                    );
                } else if (setting == ProposalType.PAUSE) {
                    token().setTransferability(
                        tokenId(),
                        !token().transferable(tokenId())
                    );
                } else if (setting == ProposalType.EXTENSION) {
                    for (uint256 i; i < calls.length; ++i) {
                        if (calls[i].value != 0)
                            extensions[calls[i].to] = !extensions[calls[i].to];

                        if (calls[i].data.length > 3)
                            KaliExtension(calls[i].to).setExtension(
                                calls[i].data
                            );
                    }
                } else if (setting == ProposalType.ESCAPE) {
                    delete proposals[calls[0].value];
                } else if (setting == ProposalType.URI) {
                    daoURI = details;
                }

                proposalStates[proposal].passed = true;
            }
        }

        delete proposals[proposal];

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
    /// Execution Logic
    /// -----------------------------------------------------------------------

    function _execute(
        Operation op,
        address to,
        uint256 value,
        bytes memory data
    ) internal virtual {
        bool success;

        if (op == Operation.call) {
            assembly {
                success := call(
                    gas(),
                    to,
                    value,
                    add(data, 0x20),
                    mload(data),
                    0,
                    0
                )
            }

            emit Executed(op, to, value, data, success);
        } else if (op == Operation.delegatecall) {
            assembly {
                data := delegatecall(
                    gas(),
                    to,
                    add(data, 0x20),
                    mload(data),
                    0,
                    0
                )
            }

            emit Executed(op, to, value, data, success);
        } else {
            assembly {
                success := create(value, add(data, 0x20), mload(data))
            }

            emit Executed(op, to, value, data, success);
        }
    }

    /// -----------------------------------------------------------------------
    /// Signature Recovery Logic
    /// -----------------------------------------------------------------------

    function _recoverSig(
        bytes32 hash,
        address user,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal view virtual {
        if (user == address(0)) revert InvalidSig();

        address signer;

        // Perform signature recovery via ecrecover.
        /// @solidity memory-safe-assembly
        assembly {
            // Copy the free memory pointer so that we can restore it later.
            let m := mload(0x40)

            // If `s` in lower half order, such that the signature is not malleable.
            if iszero(gt(s, MALLEABILITY_THRESHOLD)) {
                mstore(0x00, hash)
                mstore(0x20, v)
                mstore(0x40, r)
                mstore(0x60, s)
                pop(
                    staticcall(
                        gas(), // Amount of gas left for the transaction.
                        0x01, // Address of `ecrecover`.
                        0x00, // Start of input.
                        0x80, // Size of input.
                        0x40, // Start of output.
                        0x20 // Size of output.
                    )
                )
                // Restore the zero slot.
                mstore(0x60, 0)
                // `returndatasize()` will be `0x20` upon success, and `0x00` otherwise.
                signer := mload(sub(0x60, returndatasize()))
            }
            // Restore the free memory pointer.
            mstore(0x40, m)
        }

        // If recovery doesn't match `user`, verify contract signature with ERC1271.
        if (user != signer) {
            bool valid;

            /// @solidity memory-safe-assembly
            assembly {
                // Load the free memory pointer.
                // Simply using the free memory usually costs less if many slots are needed.
                let m := mload(0x40)

                // `bytes4(keccak256("isValidSignature(bytes32,bytes)"))`.
                let f := shl(224, 0x1626ba7e)
                // Write the abi-encoded calldata into memory, beginning with the function selector.
                mstore(m, f) // `bytes4(keccak256("isValidSignature(bytes32,bytes)"))`.
                mstore(add(m, 0x04), hash)
                mstore(add(m, 0x24), 0x40) // The offset of the `signature` in the calldata.
                mstore(add(m, 0x44), 65) // Store the length of the signature.
                mstore(add(m, 0x64), r) // Store `r` of the signature.
                mstore(add(m, 0x84), s) // Store `s` of the signature.
                mstore8(add(m, 0xa4), v) // Store `v` of the signature.

                valid := and(
                    and(
                        // Whether the returndata is the magic value `0x1626ba7e` (left-aligned).
                        eq(mload(0x00), f),
                        // Whether the returndata is exactly 0x20 bytes (1 word) long.
                        eq(returndatasize(), 0x20)
                    ),
                    // Whether the staticcall does not revert.
                    // This must be placed at the end of the `and` clause,
                    // as the arguments are evaluated from right to left.
                    staticcall(
                        gas(), // Remaining gas.
                        user, // The `user` address.
                        m, // Offset of calldata in memory.
                        0xa5, // Length of calldata in memory.
                        0x00, // Offset of returndata.
                        0x20 // Length of returndata to write.
                    )
                )
            }

            if (!valid) revert InvalidSig();
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
        if (!extensions[msg.sender]) revert Unauthorized();

        _;
    }

    function relay(
        Call calldata call
    ) public payable virtual onlyExtension nonReentrant {
        _execute(call.op, call.to, call.value, call.data);
    }

    function mint(
        KeepTokenManager source,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) public payable virtual onlyExtension nonReentrant {
        source.mint(to, id, amount, data);
    }

    function burn(
        KeepTokenManager source,
        address from,
        uint256 id,
        uint256 amount
    ) public payable virtual onlyExtension nonReentrant {
        source.burn(from, id, amount);
    }

    function setTransferability(
        KeepTokenManager source,
        uint256 id,
        bool on
    ) public payable virtual onlyExtension nonReentrant {
        source.setTransferability(id, on);
    }

    function setExtension(address extension, bool on) public payable virtual {
        if (!extensions[msg.sender])
            if (msg.sender != address(this)) revert Unauthorized();

        extensions[extension] = on;

        emit ExtensionSet(extension, on);
    }

    function setURI(
        string calldata _daoURI
    ) public payable virtual onlyExtension {
        daoURI = _daoURI;

        emit URIset(_daoURI);
    }

    function deleteProposal(uint256 proposal) public payable virtual {
        if (!extensions[msg.sender])
            if (msg.sender != address(this)) revert Unauthorized();

        if (proposals[proposal].creationTime == 0) revert InvalidProposal();

        delete proposals[proposal];

        proposalStates[proposal].processed = true;
    }

    function updateGovSettings(
        uint256 _votingPeriod,
        uint256 _gracePeriod,
        uint256 _quorum,
        uint256 _supermajority,
        uint256[2] calldata _typeSetting
    ) public payable virtual {
        if (!extensions[msg.sender])
            if (msg.sender != address(this)) revert Unauthorized();

        if (_votingPeriod != 0)
            if (_votingPeriod <= 365 days)
                votingPeriod = uint120(_votingPeriod);

        if (_gracePeriod <= 365 days) gracePeriod = uint120(_gracePeriod);

        if (_quorum <= 100) quorum = uint8(_quorum);

        if (_supermajority > 51)
            if (_supermajority <= 100) supermajority = uint8(_supermajority);

        if (_typeSetting[0] <= 11)
            if (_typeSetting[1] <= 3)
                proposalVoteTypes[ProposalType(_typeSetting[0])] = VoteType(
                    _typeSetting[1]
                );

        emit GovSettingsUpdated(
            _votingPeriod,
            _gracePeriod,
            _quorum,
            _supermajority,
            _typeSetting
        );
    }
}
