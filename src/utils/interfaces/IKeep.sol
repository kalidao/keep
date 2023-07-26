// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IKeep {
    event ApprovalForAll(
        address indexed owner,
        address indexed operator,
        bool approved
    );
    event DelegateChanged(
        address indexed delegator,
        address indexed fromDelegate,
        address indexed toDelegate,
        uint256 id
    );
    event DelegateVotesChanged(
        address indexed delegate,
        uint256 indexed id,
        uint256 previousBalance,
        uint256 newBalance
    );
    event Executed(
        uint256 indexed nonce,
        uint8 op,
        address to,
        uint256 value,
        bytes data
    );
    event Multirelayed(Call[] calls);
    event PermissionSet(address indexed operator, uint256 indexed id, bool on);
    event QuorumSet(uint256 threshold);
    event Relayed(Call call);
    event TransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] amounts
    );
    event TransferSingle(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 id,
        uint256 amount
    );
    event TransferabilitySet(
        address indexed operator,
        uint256 indexed id,
        bool on
    );
    event URI(string value, uint256 indexed id);
    event UserPermissionSet(
        address indexed operator,
        address indexed to,
        uint256 indexed id,
        bool on
    );

    struct Call {
        uint8 op;
        address to;
        uint256 value;
        bytes data;
    }

    struct Signature {
        address user;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    function DOMAIN_SEPARATOR() external view returns (bytes32);

    function balanceOf(address, uint256) external view returns (uint256);

    function balanceOfBatch(
        address[] memory owners,
        uint256[] memory ids
    ) external view returns (uint256[] memory balances);

    function burn(address from, uint256 id, uint256 amount) external payable;

    function checkpoints(
        address,
        uint256,
        uint256
    ) external view returns (uint40 fromTimestamp, uint216 votes);

    function delegate(address delegatee, uint256 id) external payable;

    function delegateBySig(
        address delegator,
        address delegatee,
        uint256 id,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable;

    function delegates(
        address account,
        uint256 id
    ) external view returns (address);

    function execute(
        uint8 op,
        address to,
        uint256 value,
        bytes memory data,
        Signature[] memory sigs
    ) external payable;

    function getCurrentVotes(
        address account,
        uint256 id
    ) external view returns (uint256);

    function getPastVotes(
        address account,
        uint256 id,
        uint256 timestamp
    ) external view returns (uint256);

    function getPriorVotes(
        address account,
        uint256 id,
        uint256 timestamp
    ) external view returns (uint256);

    function getVotes(
        address account,
        uint256 id
    ) external view returns (uint256);

    function initialize(
        Call[] memory calls,
        address[] memory signers,
        uint256 threshold
    ) external payable;

    function isApprovedForAll(address, address) external view returns (bool);

    function mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) external payable;

    function multicall(
        bytes[] memory data
    ) external payable returns (bytes[] memory);

    function multirelay(Call[] memory calls) external payable;

    function name() external pure returns (string memory);

    function nonce() external view returns (uint120);

    function nonces(address) external view returns (uint256);

    function numCheckpoints(address, uint256) external view returns (uint256);

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) external payable returns (bytes4);

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) external payable returns (bytes4);

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) external payable returns (bytes4);

    function permissioned(uint256) external view returns (bool);

    function permit(
        address owner,
        address operator,
        bool approved,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable;

    function quorum() external view returns (uint120);

    function relay(Call memory call) external payable;

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) external payable;

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) external payable;

    function setApprovalForAll(
        address operator,
        bool approved
    ) external payable;

    function setPermission(uint256 id, bool on) external payable;

    function setQuorum(uint256 threshold) external payable;

    function setTransferability(uint256 id, bool on) external payable;

    function setURI(uint256 id, string memory tokenURI) external payable;

    function setUserPermission(
        address to,
        uint256 id,
        bool on
    ) external payable;

    function supportsInterface(bytes4 interfaceId) external view returns (bool);

    function totalSupply(uint256) external view returns (uint256);

    function transferable(uint256) external view returns (bool);

    function uri(uint256 id) external view returns (string memory);

    function userPermissioned(address, uint256) external view returns (bool);
}
