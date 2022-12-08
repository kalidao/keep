// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Call, Operation, Keep} from "../src/Keep.sol";
import {KeepFactory} from "../src/KeepFactory.sol";
import {ProjectManager, Status, Reward} from "../src/extensions/manager/ProjectManager.sol";

import "@std/Test.sol";
import {MockERC20} from "@solbase/test/utils/mocks/MockERC20.sol";

error NotAuthorized();

error InvalidEthReward();

contract ProjectManagerTest is Test {
    Keep public keep;
    KeepFactory public factory;

    ProjectManager public manager;

    Call[] public calls;

    uint256 public immutable MINT_KEY = uint32(keep.mint.selector);

    uint256 public immutable SIGNER_KEY = uint32(keep.execute.selector);

    bytes32 public constant MOCK_NAME =
        0x5445535400000000000000000000000000000000000000000000000000000000;

    address internal constant ZERO = address(0);
    
    // Manager
    address internal constant ALICE = 0x503408564C50b43208529faEf9bdf9794c015d52;

    // Contributor
    address internal constant BOB = 0x001d3F1ef827552Ae1114027BD3ECF1f086bA0F9;

    // Bystander
    address internal constant CHARLIE = address(3);

    MockERC20 internal mockDai;

    address[] public signers;

    function setUp() public payable {
        // Setup base.
        keep = new Keep(Keep(vm.addr(1)));
        factory = new KeepFactory(keep);
        manager = new ProjectManager();

        // Setup Keep. 
        signers.push(vm.addr(2));

        keep = Keep(factory.determineKeep(MOCK_NAME));
        factory.deployKeep(MOCK_NAME, calls, signers, 1);

        // Enable ProjectManager via mint key.
        vm.prank(address(keep));
        keep.mint(address(manager), MINT_KEY, 1, "");
    }

    function testSetExtensionWithoutMatchingBudget(uint256 budget) public payable {
        vm.assume(budget > 2 ether);
        vm.deal(address(keep), budget);
        
        // Set Extension
        bytes[] memory data = new bytes[](1);
        bytes memory data1 = abi.encode(
            0,
            Status.ACTIVE, 
            ALICE, 
            Reward.ETH, 
            ZERO,
            budget,
            1673161643,
            "hello"
        );
        data[0] = data1;

        vm.prank(address(keep));
        vm.expectRevert(InvalidEthReward.selector);
        manager.setExtension{value: budget - 1 ether} (data);
    }

    function testSingleProjectSingleContributorWithEther(uint256 budget, uint256 reward) public payable {
        vm.assume(budget > reward);
        vm.assume(reward > 1 ether);

        vm.deal(address(keep), budget);
        
        // Set Extension
        bytes[] memory data = new bytes[](1);
        bytes memory data1 = abi.encode(
            0,
            Status.ACTIVE, 
            ALICE, 
            Reward.ETH, 
            ZERO,
            budget,
            1673161643,
            "hello"
        );
        data[0] = data1;

        vm.prank(address(keep));
        manager.setExtension{value: budget} (data);
        assertEq(address(manager).balance, budget);

        // Call Extension
        bytes[] memory callData = new bytes[](1);
        bytes memory callData1 = abi.encode(1, BOB,reward);
        callData[0] = callData1;

        vm.prank(address(ALICE));
        manager.callExtension(callData);
        assertEq(address(BOB).balance, reward);
    }

    function testSingleProjectSingleContributorWithErc20(uint256 budget, uint256 reward) public payable {
        mockDai = new MockERC20("Dai", "DAI", 18);
        mockDai.mint(address(ALICE), 1_000 ether);

        vm.assume(budget > reward);
        vm.assume(reward > 1 ether);
        
        // Set Extension
        bytes[] memory data = new bytes[](1);
        bytes memory data1 = abi.encode(
            0,
            Status.ACTIVE, 
            ALICE, 
            Reward.ETH, 
            ZERO,
            budget,
            1673161643,
            "hello"
        );
        data[0] = data1;

        vm.prank(address(keep));
        manager.setExtension{value: budget} (data);
        assertEq(address(manager).balance, budget);

        // Call Extension
        bytes[] memory callData = new bytes[](1);
        bytes memory callData1 = abi.encode(1, BOB,reward);
        callData[0] = callData1;

        vm.prank(address(ALICE));
        manager.callExtension(callData);
        assertEq(address(BOB).balance, reward);
    }

    function testUnauthorizedSingleProjectSingleContributorWithEther(uint256 budget, uint256 reward) public payable {
        vm.assume(budget > reward);
        vm.assume(reward > 1 ether);

        vm.deal(address(keep), budget);
        
        // Set Extension
        bytes[] memory data = new bytes[](1);
        bytes memory data1 = abi.encode(
            0,
            Status.ACTIVE, 
            ALICE, 
            Reward.ETH, 
            ZERO,
            budget,
            1673161643,
            "hello"
        );
        data[0] = data1;

        vm.prank(address(keep));
        manager.setExtension{value: budget} (data);
        assertEq(address(manager).balance, budget);

        // Call Extension
        bytes[] memory callData = new bytes[](1);
        bytes memory callData1 = abi.encode(1, BOB,reward);
        callData[0] = callData1;

        vm.prank(address(CHARLIE));
        vm.expectRevert(NotAuthorized.selector);
        manager.callExtension(callData);
    }
}
