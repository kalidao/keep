// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Multicallable, Call, Keep} from "./Keep.sol";
import {LibClone} from "./utils/LibClone.sol";

/// @notice Keep Factory.
contract KeepFactory is Multicallable {
    /// -----------------------------------------------------------------------
    /// Library Usage
    /// -----------------------------------------------------------------------

    using LibClone for address;

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event Deployed(address indexed keep, uint256 threshold);

    /// -----------------------------------------------------------------------
    /// Immutables
    /// -----------------------------------------------------------------------

    address internal immutable keepTemplate;

    IStakeManager internal constant entryPoint =
        IStakeManager(0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789);

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor(address _keepTemplate) payable {
        keepTemplate = _keepTemplate;
    }

    /// -----------------------------------------------------------------------
    /// Deployment Logic
    /// -----------------------------------------------------------------------

    function determineKeep(bytes32 name) public view virtual returns (address) {
        return
            keepTemplate.predictDeterministicAddress(
                abi.encodePacked(name),
                name,
                address(this)
            );
    }

    function deployKeep(
        bytes32 name, // create2 salt.
        Call[] calldata calls,
        address[] calldata signers,
        uint256 threshold
    ) public payable virtual returns (address keep) {
        keep = keepTemplate.cloneDeterministic(abi.encodePacked(name), name);

        Keep(keep).initialize{value: msg.value}(calls, signers, threshold);

        emit Deployed(keep, threshold);
    }

    /// -----------------------------------------------------------------------
    /// ERC4337 Staking Logic
    /// -----------------------------------------------------------------------

    function addStake(uint32 unstakeDelaySec) external payable {
        entryPoint.addStake{value: msg.value}(unstakeDelaySec);
    }

    function unlockStake() external {
        entryPoint.unlockStake();
    }

    function withdrawStake(address payable withdrawAddress) external {
        entryPoint.withdrawStake(withdrawAddress);
    }
}

/**
 * Manage deposits and stakes.
 * Deposit is just a balance used to pay for UserOperations (either by a paymaster or an account).
 * Stake is value locked for at least "unstakeDelay" by the staked entity.
 */
interface IStakeManager {
    event Deposited(address indexed account, uint256 totalDeposit);

    event Withdrawn(
        address indexed account,
        address withdrawAddress,
        uint256 amount
    );

    // Emitted when stake or unstake delay are modified.
    event StakeLocked(
        address indexed account,
        uint256 totalStaked,
        uint256 unstakeDelaySec
    );

    // Emitted once a stake is scheduled for withdrawal.
    event StakeUnlocked(address indexed account, uint256 withdrawTime);

    event StakeWithdrawn(
        address indexed account,
        address withdrawAddress,
        uint256 amount
    );

    /**
     * @param deposit         - The entity's deposit.
     * @param staked          - True if this entity is staked.
     * @param stake           - Actual amount of ether staked for this entity.
     * @param unstakeDelaySec - Minimum delay to withdraw the stake.
     * @param withdrawTime    - First block timestamp where 'withdrawStake' will be callable, or zero if already locked.
     * @dev Sizes were chosen so that (deposit,staked, stake) fit into one cell (used during handleOps)
     *      and the rest fit into a 2nd cell.
     *      - 112 bit allows for 10^15 eth
     *      - 48 bit for full timestamp
     *      - 32 bit allows 150 years for unstake delay
     */
    struct DepositInfo {
        uint112 deposit;
        bool staked;
        uint112 stake;
        uint32 unstakeDelaySec;
        uint48 withdrawTime;
    }

    // API struct used by getStakeInfo and simulateValidation.
    struct StakeInfo {
        uint256 stake;
        uint256 unstakeDelaySec;
    }

    /**
     * Get deposit info.
     * @param account - The account to query.
     * @return info   - Full deposit information of given account.
     */
    function getDepositInfo(
        address account
    ) external view returns (DepositInfo memory info);

    /**
     * Get account balance.
     * @param account - The account to query.
     * @return        - The deposit (for gas payment) of the account.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * Add to the deposit of the given account.
     * @param account - The account to add to.
     */
    function depositTo(address account) external payable;

    /**
     * Add to the account's stake - amount and delay
     * any pending unstake is first cancelled.
     * @param _unstakeDelaySec - The new lock duration before the deposit can be withdrawn.
     */
    function addStake(uint32 _unstakeDelaySec) external payable;

    /**
     * Attempt to unlock the stake.
     * The value can be withdrawn (using withdrawStake) after the unstake delay.
     */
    function unlockStake() external;

    /**
     * Withdraw from the (unlocked) stake.
     * Must first call unlockStake and wait for the unstakeDelay to pass.
     * @param withdrawAddress - The address to send withdrawn value.
     */
    function withdrawStake(address payable withdrawAddress) external;

    /**
     * Withdraw from the deposit.
     * @param withdrawAddress - The address to send withdrawn value.
     * @param withdrawAmount  - The amount to withdraw.
     */
    function withdrawTo(
        address payable withdrawAddress,
        uint256 withdrawAmount
    ) external;
}
