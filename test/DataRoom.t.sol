// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Call, Operation, Keep} from "../src/Keep.sol";
import {KeepFactory} from "../src/KeepFactory.sol";
import {DataRoom} from "../src/extensions/storage/DataRoom.sol";

import "@std/Test.sol";

contract DataRoomTest is Test {
    Keep public keep;
    KeepFactory public factory;

    DataRoom public dataRoom;

    Call[] public calls;

    uint256 public immutable MINT_KEY = uint32(keep.mint.selector);

    uint256 public immutable SIGNER_KEY = uint32(keep.execute.selector);

    bytes32 public constant MOCK_NAME =
        0x5445535400000000000000000000000000000000000000000000000000000000;

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

    function testUnauthorizedInitializationByUser(address _alice) public payable {
        vm.assume(_alice != address(keep));

        address[] memory _users = new address[](0);
        bool[] memory _authorize = new bool[](0);

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

    function testUnauthorizedPermissionSetting(address _alice) public payable {
        vm.assume(_alice != address(keep));

        address[] memory _users = new address[](1);
        _users[0] = _alice;

        bool[] memory _authorize = new bool[](1);
        _authorize[0] = false;

        vm.prank(address(keep));
        dataRoom.setPermission(address(keep), _users, _authorize);

        bool alicePermissioned = dataRoom.authorized(address(keep), address(_alice));
        assertEq(alicePermissioned, false);

        vm.prank(address(_alice));
        vm.expectRevert();
        dataRoom.setPermission(address(keep), _users, _authorize);
    }

    function testSetRecordByKeep(
        address _alice, 
        bool _auth, 
        string calldata _data0, 
        string calldata _data1
    ) public payable {
        vm.assume(_alice != address(keep));

        address[] memory _users = new address[](1);
        _users[0] = _alice;

        bool[] memory _authorize = new bool[](1);
        _authorize[0] = _auth;

        vm.prank(address(keep));
        dataRoom.setPermission(address(keep), _users, _authorize);

        bool keepPermissioned = dataRoom.authorized(address(keep), address(keep));
        assertEq(keepPermissioned, true);

        string[] memory _data = new string[](2);
        _data[0] = _data0;
        _data[1] = _data1;

        vm.prank(address(keep));
        dataRoom.setRecord(address(keep), _data);
        
        string[] memory returnData = dataRoom.getRoom(address(keep));
        assertEq(returnData[1], _data1);
    }

    function testSetRecordByAuthorized(
        address _alice, 
        string calldata _data0, 
        string calldata _data1
    ) public payable {
        vm.assume(_alice != address(keep));

        address[] memory _users = new address[](1);
        _users[0] = _alice;

        bool[] memory _authorize = new bool[](1);
        _authorize[0] = true;

        vm.prank(address(keep));
        dataRoom.setPermission(address(keep), _users, _authorize);

        bool keepPermissioned = dataRoom.authorized(address(keep), address(keep));
        assertEq(keepPermissioned, true);
        bool alicePermissioned = dataRoom.authorized(address(keep), address(_alice));
        assertEq(alicePermissioned, true);

        string[] memory _data = new string[](2);
        _data[0] = _data0;
        _data[1] = _data1;

        vm.prank(address(_alice));
        dataRoom.setRecord(address(keep), _data);

        string[] memory returnData = dataRoom.getRoom(address(keep));
        assertEq(returnData[1], _data1);
    }

    function testSetRecordByUnauthorized(
        address _alice, 
        string calldata _data0, 
        string calldata _data1
    ) public payable {
        vm.assume(_alice != address(keep));

        address[] memory _users = new address[](0);
        bool[] memory _authorize = new bool[](0);

        vm.prank(address(keep));
        dataRoom.setPermission(address(keep), _users, _authorize);

        bool keepPermissioned = dataRoom.authorized(address(keep), address(keep));
        assertEq(keepPermissioned, true);

        string[] memory _data = new string[](2);
        _data[0] = _data0;
        _data[1] = _data1;

        vm.prank(address(_alice));
        vm.expectRevert();
        dataRoom.setRecord(address(keep), _data);        
    }
}
