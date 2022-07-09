// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {
    Operation, 
    Call, 
    Signature, 
    KaliClub
} from "../KaliClub.sol";
import {
    KaliClubFactory
} from "../KaliClubFactory.sol";

import {MockERC20} from "@solmate/test/utils/mocks/MockERC20.sol";

import "@std/Test.sol";

contract ClubTest is Test {
    using stdStorage for StdStorage;

    address clubAddr;
    address clubAddrRepeat;
    KaliClub club;
    KaliClub clubRepeat;
    KaliClubFactory factory;
    MockERC20 mockDai;

    uint32 internal EXECUTE_ID;

    /// @dev Users

    uint256 immutable alicesPk =
        0x60b919c82f0b4791a5b7c6a7275970ace1748759ebdaa4076d7eeed9dbcff3c3;
    address public immutable alice = 0x503408564C50b43208529faEf9bdf9794c015d52;

    uint256 immutable bobsPk =
        0xf8f8a2f43c8376ccb0871305060d7b27b0554d2cc72bccf41b2705608452f315;
    address public immutable bob = 0x001d3F1ef827552Ae1114027BD3ECF1f086bA0F9;

    uint256 immutable charliesPk =
        0xb9dee2522aae4d21136ba441f976950520adf9479a3c0bda0a88ffc81495ded3;
    address public immutable charlie =
        0xccc4A5CeAe4D88Caf822B355C02F9769Fb6fd4fd;

    uint256 immutable nullPk =
        0x8b2ed20f3cc3dd482830910365cfa157e7568b9c3fa53d9edd3febd61086b9be;
    address public immutable nully = 0x0ACDf2aC839B7ff4cd5F16e884B2153E902253f2;

    /// @dev Helpers

    Call[] calls;

    uint256 chainId;

    bytes32 name =
        0x5445535400000000000000000000000000000000000000000000000000000000;

    bytes32 name2 =
        0x5445535432000000000000000000000000000000000000000000000000000000;

    function getDigest(
        Operation op,
        address to,
        uint256 value,
        bytes memory data,
        uint256 nonce,
        bytes32 domainSeparator
    ) internal pure returns (bytes32) {
        return 
            keccak256(
                abi.encodePacked(
                    '\x19\x01',
                    domainSeparator,
                    keccak256(
                        abi.encode(
                            keccak256(
                                'Execute(Operation op,address to,uint256 value,bytes data,uint256 nonce)'
                            ),
                            op,
                            to,
                            value,
                            data,
                            nonce
                        )
                    )
                )
            );
    }

    function computeDomainSeparator(address addr) internal view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    keccak256(
                        'EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'
                    ),
                    keccak256(bytes('KaliClub')),
                    keccak256('1'),
                    block.chainid,
                    addr
                )
            );
    }

    function writeTokenBalance(
        address who,
        address token,
        uint256 amt
    ) internal {
        stdstore
            .target(token)
            .sig(MockERC20(token).balanceOf.selector)
            .with_key(who)
            .checked_write(amt);
    }

    function signExecution(
        uint256 pk,
        Operation op,
        address to,
        uint256 value,
        bytes memory data
    ) internal returns (Signature memory sig) {
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(
            pk,
            getDigest(op, address(to), value, data, club.nonce(), computeDomainSeparator(address(club)))
        );
        // set 'wrong v' to return null signer for tests
        if (pk == nullPk) v = 17;

        sig = Signature({v: v, r: r, s: s});
    }

    /// -----------------------------------------------------------------------
    /// Club Setup Tests
    /// -----------------------------------------------------------------------

    /// @notice Set up the testing suite

    function setUp() public {
        club = new KaliClub();
        mockDai = new MockERC20('Dai', 'DAI', 18);
        chainId = block.chainid;

        // 1B mockDai!
        mockDai.mint(address(this), 1000000000 * 1e18);

        // Create the factory
        factory = new KaliClubFactory(club);

        // Create the Signer[]
        address[] memory signers = new address[](2);
        signers[0] = alice > bob
            ? bob
            : alice;
        signers[1] = alice > bob
            ? alice
            : bob;

        (clubAddr, ) = factory.determineClub(name); 
        club = KaliClub(clubAddr);
        // The factory is fully tested in KaliClubFactory.t.sol
        factory.deployClub(
            calls,
            signers,
            2,
            name
        );

        EXECUTE_ID = uint32(uint256(bytes32(club.execute.selector)));

        mockDai.approve(address(club), type(uint256).max);
    }

    /// @notice Check setup malconditions

    function testRepeatClubSetup() public {
        clubRepeat = new KaliClub();

        // Create the Signer[]
        address[] memory signers = new address[](2);
        signers[0] = alice > bob
            ? bob
            : alice;
        signers[1] = alice > bob
            ? alice
            : bob;
        
        (clubAddrRepeat, ) = factory.determineClub(name2); 
        clubRepeat = KaliClub(clubAddrRepeat);
        factory.deployClub(
            calls,
            signers,
            2,
            name2
        );

        vm.expectRevert(bytes4(keccak256("ALREADY_INIT()")));
        clubRepeat.init(calls, signers, 2);
    }

    function testZeroQuorumSetup() public {
        // Create the Signer[]
        address[] memory signers = new address[](2);
        signers[0] = alice > bob
            ? bob
            : alice;
        signers[1] = alice > bob
            ? alice
            : bob;

        vm.expectRevert(bytes(''));
        factory.deployClub(
            calls,
            signers,
            0,
            name2
        );
    }

    function testExcessiveQuorumSetup() public {
        // Create the Signer[]
        address[] memory signers = new address[](2);
        signers[0] = alice > bob
            ? bob
            : alice;
        signers[1] = alice > bob
            ? alice
            : bob;

        vm.expectRevert(bytes4(keccak256("QUORUM_OVER_SUPPLY()")));
        factory.deployClub(
            calls,
            signers,
            3,
            name2
        );
    }

    function testOutOfOrderSignerSetup() public {
        // Create the Signer[]
        address[] memory signers = new address[](2);
        signers[0] = alice > bob
            ? alice
            : bob;
        signers[1] = alice > bob
            ? bob
            : alice;

        vm.expectRevert(bytes4(keccak256("INVALID_SIG()")));
        factory.deployClub(
            calls,
            signers,
            2,
            name2
        );
    }

    /// -----------------------------------------------------------------------
    /// Club State Tests
    /// -----------------------------------------------------------------------

    function testNonce() public view {
        assert(club.nonce() == 1);
    }
    /*
    function testQuorum() public {
        assert(club.quorum() == 2);

        vm.prank(address(club));
        club.mintSigner(charlie);
        vm.stopPrank();

        vm.prank(address(club));
        club.setQuorum(3);
        vm.stopPrank();

        assert(club.quorum() == 3);
    }
    */
    function testTotalSignerSupply() public view {
        assert(club.totalSupply(EXECUTE_ID) == 2);
    }

    /// -----------------------------------------------------------------------
    /// Operations Tests
    /// -----------------------------------------------------------------------

    /// @notice Check execution
    
    function testExecuteGovernance() public {
        uint256 nonceInit = club.nonce();
        address aliceAddress = address(alice);

        mockDai.transfer(address(club), 100);

        startHoax(address(club), address(club), type(uint256).max);
        club.mint(alice, uint256(bytes32(club.batchExecute.selector)), 1, '');
        vm.stopPrank();

        startHoax(address(alice), address(alice), type(uint256).max);

        bytes memory data = "";

        assembly {
            mstore(add(data, 0x20), shl(0xE0, 0xa9059cbb)) // transfer(address,uint256)
            mstore(add(data, 0x24), aliceAddress)
            mstore(add(data, 0x44), 100)
            mstore(data, 0x44)
            // Update free memory pointer
            mstore(0x40, add(data, 0x100))
        }

        Call[] memory call = new Call[](1);

        call[0].op = Operation.call;
        call[0].to = address(mockDai);
        call[0].value = 0;
        call[0].data = data;

        club.batchExecute(call);
        vm.stopPrank();
        assert(mockDai.balanceOf(alice) == 100);
        uint256 nonceAfter = club.nonce();
        assert((nonceInit + 1) == nonceAfter);
    }
    
    function testExecuteCallWithSignatures() public {
        mockDai.transfer(address(club), 100);
        address aliceAddress = alice;
        bytes memory tx_data = '';

        assembly {
            mstore(add(tx_data, 0x20), shl(0xE0, 0xa9059cbb)) // transfer(address,uint256)
            mstore(add(tx_data, 0x24), aliceAddress)
            mstore(add(tx_data, 0x44), 100)
            mstore(tx_data, 0x44)
            // Update free memory pointer
            mstore(0x40, add(tx_data, 0x80))
        }

        Signature[] memory sigs = new Signature[](2);

        Signature memory aliceSig;
        Signature memory bobSig;

        aliceSig = signExecution(alicesPk, Operation.call, address(mockDai), 0, tx_data);
        bobSig = signExecution(bobsPk, Operation.call, address(mockDai), 0, tx_data);

        sigs[0] = alice > bob ? bobSig : aliceSig;
        sigs[1] = alice > bob ? aliceSig : bobSig;

        // Execute tx
        club.execute(Operation.call, address(mockDai), 0, tx_data, sigs);
    }

    function testExecuteDelegateCallWithSignatures() public {
        mockDai.transfer(address(club), 100);
        address aliceAddress = alice;
        bytes memory tx_data = '';

        assembly {
            mstore(add(tx_data, 0x20), shl(0xE0, 0x70a08231)) // balanceOf(address)
            mstore(add(tx_data, 0x24), aliceAddress)
            mstore(tx_data, 0x24)
            // Update free memory pointer
            mstore(0x40, add(tx_data, 0x60))
        }

        Signature[] memory sigs = new Signature[](2);

        Signature memory aliceSig;
        Signature memory bobSig;

        aliceSig = signExecution(alicesPk, Operation.delegatecall, address(mockDai), 0, tx_data);
        bobSig = signExecution(bobsPk, Operation.delegatecall, address(mockDai), 0, tx_data);

        sigs[0] = alice > bob ? bobSig : aliceSig;
        sigs[1] = alice > bob ? aliceSig : bobSig;

        // Execute tx
        club.execute(Operation.delegatecall, address(mockDai), 0, tx_data, sigs);
    }

    /// @notice Check execution malconditions
    
    function testExecuteWithImproperSignatures() public {
        mockDai.transfer(address(club), 100);
        address aliceAddress = alice;
        bytes memory tx_data = '';

        assembly {
            mstore(add(tx_data, 0x20), shl(0xE0, 0xa9059cbb)) // transfer(address,uint256)
            mstore(add(tx_data, 0x24), aliceAddress)
            mstore(add(tx_data, 0x44), 100)
            mstore(tx_data, 0x44)
            // Update free memory pointer
            mstore(0x40, add(tx_data, 0x80))
        }

        Signature[] memory sigs = new Signature[](2);

        Signature memory aliceSig;
        Signature memory charlieSig;

        aliceSig = signExecution(alicesPk, Operation.call, address(mockDai), 0, tx_data);
        charlieSig = signExecution(
            charliesPk,
            Operation.call,
            address(mockDai),
            0,
            tx_data
        );

        sigs[0] = alice > charlie ? charlieSig : aliceSig;
        sigs[1] = alice > charlie ? aliceSig : charlieSig;

        vm.expectRevert(bytes4(keccak256("INVALID_SIG()")));
        // Execute tx
        club.execute(Operation.call, address(mockDai), 0, tx_data, sigs);
    }

    function testExecuteWithSignaturesOutOfOrder() public {
        mockDai.transfer(address(club), 100);
        address aliceAddress = alice;
        bytes memory tx_data = "";

        assembly {
            mstore(add(tx_data, 0x20), shl(0xE0, 0xa9059cbb)) // transfer(address,uint256)
            mstore(add(tx_data, 0x24), aliceAddress)
            mstore(add(tx_data, 0x44), 100)
            mstore(tx_data, 0x44)
            // Update free memory pointer
            mstore(0x40, add(tx_data, 0x80))
        }

        Signature[] memory sigs = new Signature[](2);

        Signature memory aliceSig;
        Signature memory bobSig;

        aliceSig = signExecution(alicesPk, Operation.call, address(mockDai), 0, tx_data);
        bobSig = signExecution(bobsPk, Operation.call, address(mockDai), 0, tx_data);

        sigs[0] = alice > bob ? aliceSig : bobSig;
        sigs[1] = alice > bob ? bobSig : aliceSig;

        vm.expectRevert(bytes4(keccak256("INVALID_SIG()")));
        // Execute tx
        club.execute(Operation.call, address(mockDai), 0, tx_data, sigs);
    }

    function testExecuteWithSignaturesRepeated() public {
        mockDai.transfer(address(club), 100);
        address aliceAddress = alice;
        bytes memory tx_data = "";

        assembly {
            mstore(add(tx_data, 0x20), shl(0xE0, 0xa9059cbb)) // transfer(address,uint256)
            mstore(add(tx_data, 0x24), aliceAddress)
            mstore(add(tx_data, 0x44), 100)
            mstore(tx_data, 0x44)
            // Update free memory pointer
            mstore(0x40, add(tx_data, 0x80))
        }

        Signature[] memory sigs = new Signature[](2);

        Signature memory aliceSig;

        aliceSig = signExecution(alicesPk, Operation.call, address(mockDai), 0, tx_data);

        sigs[0] = aliceSig;
        sigs[1] = aliceSig;

        vm.expectRevert(bytes4(keccak256("INVALID_SIG()")));
        // Execute tx
        club.execute(Operation.call, address(mockDai), 0, tx_data, sigs);
    }

    function testExecuteWithNullSignatures() public {
        mockDai.transfer(address(club), 100);
        address aliceAddress = alice;
        bytes memory tx_data = "";

        assembly {
            mstore(add(tx_data, 0x20), shl(0xE0, 0xa9059cbb)) // transfer(address,uint256)
            mstore(add(tx_data, 0x24), aliceAddress)
            mstore(add(tx_data, 0x44), 100)
            mstore(tx_data, 0x44)
            // Update free memory pointer
            mstore(0x40, add(tx_data, 0x80))
        }

        Signature[] memory sigs = new Signature[](2);

        Signature memory aliceSig;
        Signature memory nullSig;

        aliceSig = signExecution(alicesPk, Operation.call, address(mockDai), 0, tx_data);
        nullSig = signExecution(nullPk, Operation.call, address(mockDai), 0, tx_data);

        sigs[0] = alice > nully ? nullSig : aliceSig;
        sigs[1] = alice > nully ? aliceSig : nullSig;

        vm.expectRevert(bytes4(keccak256("INVALID_SIG()")));
        // Execute tx
        club.execute(Operation.call, address(mockDai), 0, tx_data, sigs);
    }
    
    /// @notice Check governance
    /*
    function testGovernMint() public {
        assert(club.totalSupply(EXECUTE_ID) == 2);
        address db = address(0xdeadbeef);

        vm.prank(address(club));
        club.mintSigner(db);
        vm.stopPrank();

        assert(club.totalSupply(EXECUTE_ID) == 3);
        assert(club.quorum() == 2);
    }

    function testGovernBurn() public {
        vm.prank(address(club));
        club.setQuorum(1);
        vm.stopPrank();

        vm.prank(address(club));
        club.burnSigner(alice);
        vm.stopPrank();

        assert(club.totalSupply(EXECUTE_ID) == 1);
        assert(club.quorum() == 1);
    }
    */
    function testMintGovernance() public {
        startHoax(charlie, charlie, type(uint256).max);
        vm.expectRevert(bytes4(keccak256("NOT_AUTHORIZED()")));
        club.mint(alice, 1, 100, '');
        vm.stopPrank();
        
        // The club itself should be able to flip governor
        startHoax(address(club), address(club), type(uint256).max);
        club.mint(charlie, uint32(uint256(bytes32(club.mint.selector))), 1, '');
        vm.stopPrank();

        startHoax(charlie, charlie, type(uint256).max);
        club.mint(alice, 1, 100, '');
        vm.stopPrank();
        assert(club.balanceOf(alice, 1) == 100);
    }
    
    function testSetTransferability(
        address dave, 
        uint256 id, 
        bool transferability
    ) public {
        if (id == 0) id = 1;
        startHoax(dave, dave, type(uint256).max);
        vm.expectRevert(bytes4(keccak256('NOT_AUTHORIZED()')));
        club.setTokenTransferability(id, transferability);
        vm.stopPrank();
        assertTrue(!club.transferable(id));

        // The club itself should be able to flip pause
        startHoax(address(club), address(club), type(uint256).max);
        club.setTokenTransferability(id, transferability);
        vm.stopPrank();
        assertTrue(club.transferable(id) == transferability);
        /*
        startHoax(address(club), address(club), type(uint256).max);
        club.mint(charlie, id, 1, '');
        vm.stopPrank();

        startHoax(charlie, charlie, type(uint256).max);
        if (transferability == false) {
            vm.expectRevert(bytes4(keccak256('NONTRANSFERABLE)')));
            club.safeTransferFrom(charlie, alice, id, 1, '');
        }
        vm.stopPrank();*/
        
    }
    
    function testUpdateURI(address dave) public {
        startHoax(dave, dave, type(uint256).max);
        vm.expectRevert(bytes4(keccak256("NOT_AUTHORIZED()")));
        club.setTokenURI(0, "new_base_uri");
        vm.stopPrank();

        // The club itself should be able to update the base uri
        startHoax(address(club), address(club), type(uint256).max);
        club.setTokenURI(0, "new_base_uri");
        vm.stopPrank();
        assertEq(
            keccak256(bytes("new_base_uri")),
            keccak256(bytes(club.uri(0)))
        );
    }
}
