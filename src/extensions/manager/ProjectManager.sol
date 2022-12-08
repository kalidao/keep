// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.14;

/// @notice ERC1155 interface to receive tokens.
/// @author Modified from Solbase (https://github.com/Sol-DAO/solbase/blob/main/src/tokens/ERC1155/ERC1155.sol)
abstract contract ERC1155TokenReceiver {
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) public payable virtual returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) public payable virtual returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }
}

/// @notice Sporos DAO project manager interface
interface IProjectManagement {
    /**
        @notice a DAO authorized manager can order mint of tokens to contributors within the project limits.
     */
    function mintShares(address to, uint256 amount) external payable;

    // Future versions will support tribute of work in exchange for tokens
    // function submitTribute(address fromContributor, bytes[] nftTribute, uint256 requestedRewardAmount) external payable;
    // function processTribute(address contributor, bytes[] nftTribute, uint256 rewardAmount) external payable;
}

abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}

/// @notice Safe ETH and ERC20 free function transfer collection that gracefully handles missing return values.
/// @author Solbase (https://github.com/Sol-DAO/solbase/blob/main/src/utils/SafeTransfer.sol)
/// @author Modified from Zolidity (https://github.com/z0r0z/zolidity/blob/main/src/utils/SafeTransfer.sol)

/// @dev The ETH transfer has failed.
error ETHTransferFailed();

/// @dev Sends `amount` (in wei) ETH to `to`.
/// Reverts upon failure.
function safeTransferETH(address to, uint256 amount) {
    assembly {
        // Transfer the ETH and check if it succeeded or not.
        if iszero(call(gas(), to, amount, 0, 0, 0, 0)) {
            // Store the function selector of `ETHTransferFailed()`.
            mstore(0x00, 0xb12d13eb)
            // Revert with (offset, size).
            revert(0x1c, 0x04)
        }
    }
}

/// @dev The ERC20 `approve` has failed.
error ApproveFailed();

/// @dev Sets `amount` of ERC20 `token` for `to` to manage on behalf of the current contract.
/// Reverts upon failure.
function safeApprove(
    address token,
    address to,
    uint256 amount
) {
    assembly {
        // We'll write our calldata to this slot below, but restore it later.
        let memPointer := mload(0x40)

        // Write the abi-encoded calldata into memory, beginning with the function selector.
        mstore(0x00, 0x095ea7b3)
        mstore(0x20, to) // Append the "to" argument.
        mstore(0x40, amount) // Append the "amount" argument.

        if iszero(
            and(
                // Set success to whether the call reverted, if not we check it either
                // returned exactly 1 (can't just be non-zero data), or had no return data.
                or(eq(mload(0x00), 1), iszero(returndatasize())),
                // We use 0x44 because that's the total length of our calldata (0x04 + 0x20 * 2)
                // Counterintuitively, this call() must be positioned after the or() in the
                // surrounding and() because and() evaluates its arguments from right to left.
                call(gas(), token, 0, 0x1c, 0x44, 0x00, 0x20)
            )
        ) {
            // Store the function selector of `ApproveFailed()`.
            mstore(0x00, 0x3e3f8f73)
            // Revert with (offset, size).
            revert(0x1c, 0x04)
        }

        mstore(0x40, memPointer) // Restore the memPointer.
    }
}

/// @dev The ERC20 `transfer` has failed.
error TransferFailed();

/// @dev Sends `amount` of ERC20 `token` from the current contract to `to`.
/// Reverts upon failure.
function safeTransfer(
    address token,
    address to,
    uint256 amount
) {
    assembly {
        // We'll write our calldata to this slot below, but restore it later.
        let memPointer := mload(0x40)

        // Write the abi-encoded calldata into memory, beginning with the function selector.
        mstore(0x00, 0xa9059cbb)
        mstore(0x20, to) // Append the "to" argument.
        mstore(0x40, amount) // Append the "amount" argument.

        if iszero(
            and(
                // Set success to whether the call reverted, if not we check it either
                // returned exactly 1 (can't just be non-zero data), or had no return data.
                or(eq(mload(0x00), 1), iszero(returndatasize())),
                // We use 0x44 because that's the total length of our calldata (0x04 + 0x20 * 2)
                // Counterintuitively, this call() must be positioned after the or() in the
                // surrounding and() because and() evaluates its arguments from right to left.
                call(gas(), token, 0, 0x1c, 0x44, 0x00, 0x20)
            )
        ) {
            // Store the function selector of `TransferFailed()`.
            mstore(0x00, 0x90b8ec18)
            // Revert with (offset, size).
            revert(0x1c, 0x04)
        }

        mstore(0x40, memPointer) // Restore the memPointer.
    }
}

/// @dev The ERC20 `transferFrom` has failed.
error TransferFromFailed();

/// @dev Sends `amount` of ERC20 `token` from `from` to `to`.
/// Reverts upon failure.
///
/// The `from` account must have at least `amount` approved for
/// the current contract to manage.
function safeTransferFrom(
    address token,
    address from,
    address to,
    uint256 amount
) {
    assembly {
        // We'll write our calldata to this slot below, but restore it later.
        let memPointer := mload(0x40)

        // Write the abi-encoded calldata into memory, beginning with the function selector.
        mstore(0x00, 0x23b872dd)
        mstore(0x20, from) // Append the "from" argument.
        mstore(0x40, to) // Append the "to" argument.
        mstore(0x60, amount) // Append the "amount" argument.

        if iszero(
            and(
                // Set success to whether the call reverted, if not we check it either
                // returned exactly 1 (can't just be non-zero data), or had no return data.
                or(eq(mload(0x00), 1), iszero(returndatasize())),
                // We use 0x64 because that's the total length of our calldata (0x04 + 0x20 * 3)
                // Counterintuitively, this call() must be positioned after the or() in the
                // surrounding and() because and() evaluates its arguments from right to left.
                call(gas(), token, 0, 0x1c, 0x64, 0x00, 0x20)
            )
        ) {
            // Store the function selector of `TransferFromFailed()`.
            mstore(0x00, 0x7939f424)
            // Revert with (offset, size).
            revert(0x1c, 0x04)
        }

        mstore(0x60, 0) // Restore the zero slot to zero.
        mstore(0x40, memPointer) // Restore the memPointer.
    }
}

/// @title ProjectManager
/// @notice Project Manger for on-chain entities.
/// @author ivelin.eth | sporosdao.eth
/// @custom:coauthor audsssy.eth | kalidao.eth

enum Reward {
    ETH,
    DAO,
    ERC20
}

enum Status {
    INACTIVE,
    ACTIVE
}

struct Project {
    address account; // the address of the DAO that this project belongs to
    Status status; // project status 
    address manager; // manager assigned to this project
    Reward reward; // type of reward to reward contributions
    address token; // token used to reward contributions
    uint256 budget; // maximum allowed tokens the manager is authorized to mint
    uint256 distributed; // amount already distributed to contributors
    uint40 deadline; // deadline date of the project
    string docs; // structured text referencing key docs for the manager's mandate
}

contract ProjectManager is ReentrancyGuard, ERC1155TokenReceiver {
    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event ExtensionSet(uint256 projectId, Project project);

    event ProjectUpdated(uint256 projectId, Project project);

    event ExtensionCalled(uint256 projectId, address indexed contributor, uint256 amount);

    /// -----------------------------------------------------------------------
    /// Custom Errors
    /// -----------------------------------------------------------------------

    error SetupFailed();

    error UpdateFailed();

    error ExpiredProject();

    error InvalidProject();

    error InactiveProject();

    error InvalidEthReward();

    error NotAuthorized();

    error InsufficientBudget();

    /// -----------------------------------------------------------------------
    /// Project Management Storage
    /// -----------------------------------------------------------------------

    uint256 public projectId;

    mapping(uint256 => Project) public projects;

    /// -----------------------------------------------------------------------
    /// ProjectManager Logic
    /// -----------------------------------------------------------------------

    function setExtension(bytes[] calldata extensionData) external payable {
        for (uint256 i; i < extensionData.length; ) {
            (
                uint256 id,
                Status status,
                address manager,
                Reward reward,
                address token,
                uint256 budget,
                uint40 deadline,
                string memory docs
            ) = abi.decode(
                extensionData[i],
                (uint256, Status, address, Reward, address, uint256, uint40, string)
            );

            if (id == 0) {
                unchecked {
                    projectId++;
                }   
                if (!_setProject(status, manager, reward, token, budget, deadline, docs))
                    revert SetupFailed(); 
            } else {
                if (status == Status.ACTIVE && manager != address(0)) revert InactiveProject();
                if (!_updateProject(id, status, manager, reward, token, budget, deadline, docs)) 
                    revert UpdateFailed();
            }

            // cannot realistically overflow
            unchecked {
                ++i;
            }
        }
    }

    function callExtension(bytes[] calldata extensionData)
        external
        payable
        nonReentrant
    {
        for (uint256 i; i < extensionData.length; ) {
            (uint256 _projectId, address contributor, uint256 amount) = abi
                .decode(extensionData[i], (uint256, address, uint256));

            Project storage project = projects[_projectId];

            if (project.account == address(0)) revert InvalidProject();

            if (project.manager != project.account && project.manager != msg.sender)
                revert NotAuthorized();

            if (project.status == Status.INACTIVE) revert InactiveProject();

            if (project.deadline < block.timestamp) revert ExpiredProject();

            if (project.budget < amount) revert InsufficientBudget();

            if (amount == 0) revert InsufficientBudget();

            project.budget -= amount;
            project.distributed += amount;

            if (project.reward == Reward.ETH) {
                safeTransferETH(contributor, amount);
            } else if (project.reward == Reward.DAO) {
                IProjectManagement(project.account).mintShares(contributor, amount);
            } else {
                safeTransferFrom(
                    project.token,
                    address(this),
                    contributor,
                    amount
                );
            }

            // cannot realistically overflow
            unchecked {
                ++i;
            }

            emit ExtensionCalled(_projectId, contributor, amount);
        }
    }

    /// -----------------------------------------------------------------------
    /// Internal Functions
    /// -----------------------------------------------------------------------
    
    function _setProject(
        Status status, 
        address manager, 
        Reward reward, 
        address token, 
        uint256 budget, 
        uint40 deadline, 
        string memory docs
    ) internal returns(bool) {
        if (reward == Reward.ETH) {
            if (msg.value != budget || reward != Reward.ETH) revert InvalidEthReward();

            projects[projectId] = Project({
                account: msg.sender,
                status: status,
                manager: manager,
                reward: reward,
                token: address(0),
                budget: budget,
                distributed: 0,
                deadline: deadline,
                docs: docs
            });
        } else if (reward == Reward.DAO) {
            safeTransferFrom(msg.sender, msg.sender, address(this), budget);

            projects[projectId] = Project({
                account: msg.sender,
                status: status,
                manager: manager,
                reward: reward,
                token: msg.sender,
                budget: budget,
                distributed: 0,
                deadline: deadline,
                docs: docs
            });
        } else {
            safeTransferFrom(token, msg.sender, address(this), budget);

            projects[projectId] = Project({
                account: msg.sender,
                status: status,
                manager: manager,
                reward: reward,
                token: token,
                budget: budget,
                distributed: 0,
                deadline: deadline,
                docs: docs
            });
        }
        
        emit ExtensionSet(projectId, projects[projectId]);

        return true;
    }

    function _updateProject(
        uint256 id,
        Status status, 
        address manager, 
        Reward reward, 
        address token, 
        uint256 budget, 
        uint40 deadline, 
        string memory docs
    ) internal returns(bool) {

        projects[id] = Project({
            account: (msg.sender != projects[id].account) ? msg.sender : projects[id].account,
            status: (status != projects[id].status) ? status : projects[id].status,
            manager: (manager != projects[id].manager) ? manager : projects[id].manager,
            reward: (reward != projects[id].reward) ? reward : projects[id].reward,
            token: (token != projects[id].token) ? token : projects[id].token,
            budget: (budget != projects[id].budget) ? budget : projects[id].budget,
            distributed: projects[id].distributed,
            deadline: (deadline != projects[id].deadline) ? deadline : projects[id].deadline,
            docs: docs
        });

        emit ProjectUpdated(id, projects[id]);

        return true;
    }
}
