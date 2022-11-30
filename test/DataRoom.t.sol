// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Call, Operation, Keep} from "../src/Keep.sol";
import {KeepFactory} from "../src/KeepFactory.sol";
import {DataRoom} from "../src/extensions/storage/DataRoom.sol";

import "@std/Test.sol";
import "@std/console2.sol";

contract DataRoomTest is Test, Keep(this) {
    Keep public keep;
    KeepFactory public factory;

    DataRoom public dataRoom;

    Call[] public calls;

    uint256 public immutable MINT_KEY = uint32(keep.mint.selector);

    uint256 public immutable SIGNER_KEY = uint32(keep.execute.selector);

    bytes32 public constant MOCK_NAME =
        0x5445535400000000000000000000000000000000000000000000000000000000;

    // address internal constant alice =
    //     0x503408564C50b43208529faEf9bdf9794c015d52;

    // address internal constant bob = 
    //     0x001d3F1ef827552Ae1114027BD3ECF1f086bA0F9;

    address[] public signers;

    function setUp() public payable {
        // Setup base.
        keep = new Keep(Keep(vm.addr(1)));
        factory = new KeepFactory(keep);
        dataRoom = new DataRoom();

        // Setup Keep. 
        signers.push(vm.addr(2));

        keep = Keep(factory.determineKeep(MOCK_NAME));
        factory.deployKeep(MOCK_NAME, calls, signers, 1);
    }

    function testInitializeRoomWithoutUser() public payable {
        address[] memory _users = new address[](0);
        bool[] memory _authorize = new bool[](0);

        vm.prank(address(keep));
        dataRoom.setPermission(address(keep), _users, _authorize);

        bool keepPermissioned = dataRoom.authorized(address(keep), address(keep));
        assertEq(keepPermissioned, true);
    }

    function testNonKeepUnauthorizedInitialization(address _alice) public payable {
        vm.assume(_alice != address(keep));

        address[] memory _users = new address[](0);
        bool[] memory _authorize = new bool[](0);

        vm.prank(address(_alice));
        vm.expectRevert();
        dataRoom.setPermission(address(keep), _users, _authorize);
    }

    function testUnauthorizedInitialization(address _alice) public payable {
        address[] memory _users = new address[](0);
        bool[] memory _authorize = new bool[](0);

        vm.prank(address(keep));
        dataRoom.setPermission(address(keep), _users, _authorize);

        vm.prank(address(_alice));
        vm.expectRevert();
        dataRoom.setPermission(address(keep), _users, _authorize);
    }

    function testInitializeRoomWithOneUser(address _alice, bool _auth) public payable {
        vm.assume(_alice != address(keep));

        address[] memory _users = new address[](1);
        _users[0] = _alice;

        bool[] memory _authorize = new bool[](1);
        _authorize[0] = _auth;

        vm.prank(address(keep));
        dataRoom.setPermission(address(keep), _users, _authorize);

        bool keepPermissioned = dataRoom.authorized(address(keep), address(keep));
        assertEq(keepPermissioned, true);
        bool alicePermissioned = dataRoom.authorized(address(keep), address(_alice));
        assertEq(alicePermissioned, _auth);
    }

    function testInitializeRoomWithMultiUser(
        address _alice, 
        bool _aliceAuth, 
        address _bob, 
        bool _bobAuth
    ) public payable {
        vm.assume(_alice != address(keep));
        vm.assume(_bob != address(keep));

        address[] memory _users = new address[](2);
        _users[0] = _alice;
        _users[1] = _bob;

        bool[] memory _authorize = new bool[](2);
        _authorize[0] = _aliceAuth;
        _authorize[1] = _bobAuth;

        vm.prank(address(keep));
        dataRoom.setPermission(address(keep), _users, _authorize);

        bool keepPermissioned = dataRoom.authorized(address(keep), address(keep));
        assertEq(keepPermissioned, true);
        bool alicePermissioned = dataRoom.authorized(address(keep), address(_alice));
        assertEq(alicePermissioned, _aliceAuth);
        bool bobPermissioned = dataRoom.authorized(address(keep), address(_bob));
        assertEq(bobPermissioned, _bobAuth);
    }
    // function testSetRecordAuthorized(string memory content) public payable {
    //     vm.prank(address(keep));
    //     dataRoom.setPermission(Location.USER, alice);

    //     vm.prank(address(alice));
    //     dataRoom.setRecord(Location.USER, content);

    //     // Check integrity of recorded data
    //     Data[] memory data = dataRoom.getCollection(Location.USER);
    //     assertEq(data[0].content, content);
    // }

    // function testSetRecordNotAuthorized(string memory content) public payable {
    //     vm.prank(address(keep));
    //     dataRoom.setPermission(Location.USER, alice);

    //     vm.prank(address(bob));
    //     vm.expectRevert();
    //     dataRoom.setRecord(Location.USER, content);
    // }
}
