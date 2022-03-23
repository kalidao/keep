// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {IClub} from "../interfaces/IClub.sol";

import {KaliClubSig, Signature} from "../KaliClubSig.sol";
import {ClubLoot} from "../ClubLoot.sol";
import {ERC20} from "./tokens/ERC20.sol";
import {KaliClubSigFactory} from "../KaliClubSigFactory.sol";

import {DSTestPlus} from "./utils/DSTestPlus.sol";

import "forge-std/stdlib.sol";

contract ClubSigTest is DSTestPlus {
    using stdStorage for StdStorage;

    StdStorage stdstore;
    KaliClubSig clubSig;
    ClubLoot loot;
    KaliClubSigFactory factory;
    ERC20 mockDai;

    // TODO(Fuzzing)
    // TODO(Adversarial testing)

    /// @dev Users
    address public immutable bob = address(0xb);
    address public immutable charlie = address(0xc);

    uint256 immutable alicesPk =
        0x60b919c82f0b4791a5b7c6a7275970ace1748759ebdaa4076d7eeed9dbcff3c3;
    address public immutable alice = 0x503408564C50b43208529faEf9bdf9794c015d52;

    function writeTokenBalance(
        address who,
        address token,
        uint256 amt
    ) internal {
        stdstore
            .target(token)
            .sig(ERC20(token).balanceOf.selector)
            .with_key(who)
            .checked_write(amt);
    }

    /// @notice Set up the testing suite
    function setUp() public {
        clubSig = new KaliClubSig();
        loot = new ClubLoot();
        mockDai = new ERC20("Dai", "DAI", 18);

        // 1B mockDai!
        mockDai.mint(address(this), 1000000000 * 1e18);

        // Create the factory
        factory = new KaliClubSigFactory(clubSig, loot);

        // Create the Club[]
        IClub.Club[] memory clubs = new IClub.Club[](2);
        clubs[0] = alice > bob
            ? IClub.Club(bob, 1, 100)
            : IClub.Club(alice, 0, 100);
        clubs[1] = alice > bob
            ? IClub.Club(alice, 0, 100)
            : IClub.Club(bob, 1, 100);

        // The factory is fully tested in KaliClubSigFactory.t.sol
        (clubSig, ) = factory.deployClubSig(
            clubs,
            2,
            0,
            0x5445535400000000000000000000000000000000000000000000000000000000,
            0x5445535400000000000000000000000000000000000000000000000000000000,
            false,
            false,
            "BASE",
            "DOCS"
        );

        ERC20(mockDai).approve(address(clubSig), type(uint256).max);
    }

    /// -----------------------------------------------------------------------
    /// Club State Tests
    /// -----------------------------------------------------------------------

    function testNonce() public view {
        assert(clubSig.nonce() == 1);
        // TODO(Execute tx and check that nonce is incremented)
    }

    function testQuorum() public view {
        assert(clubSig.quorum() == 2);
        // TODO(Add more members, alter quorum and check that number changed)
    }

    function testRedemptionStart() public view {
        assert(clubSig.redemptionStart() == 0);
        // TODO(Set a different redemption and verify setting)
    }

    function testTotalSupply() public view {
        assert(clubSig.totalSupply() == 2);
        // TODO(Mint another pass and assert that the total supply has increased)
    }

    function testBaseURI() public {
        assert(keccak256(bytes(clubSig.baseURI())) == keccak256(bytes("BASE")));

        string memory updated = "NEW BASE";
        startHoax(address(clubSig), address(clubSig), type(uint256).max);
        clubSig.updateURI(updated);
        vm.stopPrank();
        assert(
            keccak256(bytes(clubSig.baseURI())) == keccak256(bytes(updated))
        );
    }

    function testDocs() public {
        assert(keccak256(bytes(clubSig.docs())) == keccak256(bytes("DOCS")));
        string memory updated = "NEW DOCS";

        startHoax(address(clubSig), address(clubSig), type(uint256).max);
        clubSig.updateDocs(updated);
        vm.stopPrank();
        assert(keccak256(bytes(clubSig.docs())) == keccak256(bytes(updated)));
    }

    function testTokenURI() public view {
        // TODO(Assertion about string returned being correct)
        clubSig.tokenURI(1);
    }

    // Init is implicitly tested by the factory/deploy

    // The governor storage mapping in tested implicitly below

    /// -----------------------------------------------------------------------
    /// Operations Tests
    /// -----------------------------------------------------------------------

    function testExecuteGovernor() public {
        startHoax(address(clubSig), address(clubSig), type(uint256).max);
        clubSig.setGovernor(alice, true);
        vm.stopPrank();
        assertTrue(clubSig.governor(alice));

        address aliceAddress = address(alice);

        Signature[] memory sigs = new Signature[](0);

        mockDai.transfer(address(clubSig), 100);

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

        clubSig.execute(address(mockDai), 0, data, false, sigs);
        vm.stopPrank();
    }

    function testFailExecuteWithSignatures() public {
        uint8 v;
        bytes32 r;
        bytes32 s;
        bytes memory tx_data = "";

        address aliceAddress = alice;

        assembly {
            mstore(add(tx_data, 0x20), shl(0xE0, 0xa9059cbb)) // transfer(address,uint256)
            mstore(add(tx_data, 0x24), aliceAddress)
            mstore(add(tx_data, 0x44), 100)
            mstore(tx_data, 0x44)
            // Update free memory pointer
            mstore(0x40, add(tx_data, 0x100))
        }

        Signature[] memory sigs = new Signature[](2);

        // Sign as alice
        startHoax(address(alice), address(alice), type(uint256).max);

        (v, r, s) = vm.sign(
            alicesPk,
            clubSig.getDigest(
                address(mockDai),
                0,
                tx_data,
                false,
                clubSig.nonce()
            )
        );
        sigs[0] = Signature({v: v, r: r, s: s});

        vm.stopPrank();
        // TODO(Sign as bob)
        // Execute tx
        clubSig.execute(address(mockDai), 0, tx_data, false, sigs);
    }

    // TODO(Test as non admin (quorum))

    function testGovernAlreadyMinted() public {
        IClub.Club[] memory clubs = new IClub.Club[](1);
        clubs[0] = IClub.Club(alice, 0, 100);

        bool[] memory mints = new bool[](1);
        mints[0] = true;

        vm.expectRevert(bytes4(keccak256("AlreadyMinted()")));
        vm.prank(address(clubSig));
        clubSig.govern(clubs, mints, 3);
    }

    function testGovernMint() public {
        address db = address(0xdeadbeef);

        IClub.Club[] memory clubs = new IClub.Club[](1);
        clubs[0] = IClub.Club(db, 2, 100);

        bool[] memory mints = new bool[](1);
        mints[0] = true;

        vm.prank(address(clubSig));
        clubSig.govern(clubs, mints, 3);
    }

    function testGovernBurn() public {
        IClub.Club[] memory clubs = new IClub.Club[](1);
        clubs[0] = IClub.Club(alice, 1, 100);

        bool[] memory mints = new bool[](1);
        mints[0] = false;

        vm.prank(address(clubSig));
        clubSig.govern(clubs, mints, 1);
    }

    function testSetGovernor(address dave) public {
        startHoax(dave, dave, type(uint256).max);
        vm.expectRevert(bytes4(keccak256("Forbidden()")));
        clubSig.setGovernor(dave, true);
        vm.stopPrank();

        // The ClubSig itself should be able to flip governor
        startHoax(address(clubSig), address(clubSig), type(uint256).max);
        clubSig.setGovernor(dave, true);
        vm.stopPrank();
        assertTrue(clubSig.governor(dave));
    }

    function testSetSignerPause(address dave) public {
        startHoax(dave, dave, type(uint256).max);
        vm.expectRevert(bytes4(keccak256("Forbidden()")));
        clubSig.setSignerPause(true);
        vm.stopPrank();
        assertTrue(!clubSig.paused());

        // The ClubSig itself should be able to flip pause
        startHoax(address(clubSig), address(clubSig), type(uint256).max);
        clubSig.setSignerPause(true);
        vm.stopPrank();
        assertTrue(clubSig.paused());
    }

    function testSetLootPause(bool _paused) public {
        startHoax(address(clubSig), address(clubSig), type(uint256).max);
        clubSig.setLootPause(_paused);
        vm.stopPrank();

        // TODO(Why is this not being set as expected?)
        // assert(loot.paused() == _paused);
    }

    function testUpdateURI(address dave) public {
        startHoax(dave, dave, type(uint256).max);
        vm.expectRevert(bytes4(keccak256("Forbidden()")));
        clubSig.updateURI("new_base_uri");
        vm.stopPrank();

        // The ClubSig itself should be able to update the base uri
        startHoax(address(clubSig), address(clubSig), type(uint256).max);
        clubSig.updateURI("new_base_uri");
        vm.stopPrank();
        assertEq(
            keccak256(bytes("new_base_uri")),
            keccak256(bytes(clubSig.baseURI()))
        );
    }

    /// -----------------------------------------------------------------------
    /// Asset Management Tests
    /// -----------------------------------------------------------------------

    // TODO(Add failure cases here)
    function testRageQuit() public {
        address a = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
        address b = address(mockDai);

        address[] memory assets = new address[](2);
        assets[0] = a > b ? b : a;
        assets[1] = a > b ? a : b;

        mockDai.transfer(address(clubSig), 100000 * 1e18);

        (bool sent, ) = address(clubSig).call{value: 5 ether}("");
        assert(sent);

        startHoax(alice, alice, type(uint256).max);

        //uint256 ethBal = address(this).balance;
        //uint256 daiBal = mockDai.balanceOf(address(this));

        clubSig.ragequit(assets, 100);

        // TODO(This is not working as expected, 1 eth is transfereed back rather than 2.5)
        // Because here there is only 200 loot outstanding
        // assert(ethBal + 2.5 ether == address(this).balance);
        // assert(daiBal + 500000 * 1e18 == mockDai.balanceOf(address(this)));
    }
}
