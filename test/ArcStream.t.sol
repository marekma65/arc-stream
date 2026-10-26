// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../contracts/ArcStream.sol";

/// Recipient that rejects all native transfers (simulates blocklisted / broken receiver)
contract RejectingReceiver {
    receive() external payable { revert("no thanks"); }
}

/// Smart-account-like receiver whose receive() needs more than 2300 gas
contract HeavyReceiver {
    uint256 public hits;
    ArcStream public s;
    constructor(ArcStream _s) { s = _s; }
    receive() external payable { hits += 1; hits += 1; } // two SSTOREs > 2300 gas
    function doWithdraw(uint256 id) external { s.withdraw(id); }
}

/// Malicious receiver trying to re-enter withdraw()
contract Reenterer {
    ArcStream public s;
    uint256 public id;
    bool public reentryBlocked;
    constructor(ArcStream _s) { s = _s; }
    function setId(uint256 _id) external { id = _id; }
    function attack() external { s.withdraw(id); }
    receive() external payable {
        try s.withdraw(id) { } catch { reentryBlocked = true; }
    }
}

contract ArcStreamTest is Test {
    ArcStream s;
    address payable alice = payable(address(0xA11CE));
    address payable bob   = payable(address(0xB0B));

    function setUp() public {
        s = new ArcStream();
        vm.deal(alice, 1000 ether);
        vm.warp(1_000_000);
    }

    function _create(address payable to, uint256 amount, uint256 duration) internal returns (uint256 id) {
        vm.prank(alice);
        id = s.createStream{value: amount}(to, duration);
    }

    function test_CreateAndFullWithdraw() public {
        uint256 id = _create(bob, 100 ether, 100);
        vm.warp(block.timestamp + 50);
        assertEq(s.getWithdrawableAmount(id), 50 ether);
        vm.warp(block.timestamp + 1000);
        vm.prank(bob); s.withdraw(id);
        assertEq(bob.balance, 100 ether);
        assertEq(address(s).balance, 0);
    }

    function test_DustRefunded() public {
        uint256 before = alice.balance;
        uint256 id = _create(bob, 100 ether + 7, 100);
        (, , uint256 deposit, , , , , , ) = s.streams(id);
        assertEq(deposit, 100 ether);
        assertEq(alice.balance, before - 100 ether);
    }

    function test_CancelSplitsCorrectly() public {
        uint256 id = _create(bob, 100 ether, 100);
        vm.warp(block.timestamp + 30);
        uint256 before = alice.balance;
        vm.prank(alice); s.cancel(id);
        assertEq(alice.balance - before, 70 ether);       // sender refund immediately
        assertEq(s.getWithdrawableAmount(id), 30 ether);  // recipient part frozen
        vm.warp(block.timestamp + 500);
        assertEq(s.getWithdrawableAmount(id), 30 ether);  // does not grow after cancel
        vm.prank(bob); s.withdraw(id);
        assertEq(bob.balance, 30 ether);
        assertEq(address(s).balance, 0);
    }

    function test_CancelAfterPartialWithdraw() public {
        uint256 id = _create(bob, 100 ether, 100);
        vm.warp(block.timestamp + 20);
        vm.prank(bob); s.withdraw(id);                    // 20
        vm.warp(block.timestamp + 20);
        vm.prank(alice); s.cancel(id);                    // refund 60, bob owed 20
        assertEq(s.getWithdrawableAmount(id), 20 ether);
        vm.prank(bob); s.withdraw(id);
        assertEq(bob.balance, 40 ether);
        assertEq(address(s).balance, 0);
        vm.prank(bob);
        vm.expectRevert("ArcStream: nothing to withdraw");
        s.withdraw(id);
    }

    function test_CancelWorksEvenIfRecipientRejects() public {
        RejectingReceiver r = new RejectingReceiver();
        uint256 id = _create(payable(address(r)), 100 ether, 100);
        vm.warp(block.timestamp + 40);
        uint256 before = alice.balance;
        vm.prank(alice); s.cancel(id);                    // old OPNStream would revert here
        assertEq(alice.balance - before, 60 ether);
    }

    function test_SmartAccountRecipientCanWithdraw() public {
        HeavyReceiver h = new HeavyReceiver(s);
        uint256 id = _create(payable(address(h)), 100 ether, 100);
        vm.warp(block.timestamp + 100);
        h.doWithdraw(id);                                 // transfer() (2300 gas) would fail here
        assertEq(address(h).balance, 100 ether);
    }

    function test_ReentrancyBlocked() public {
        Reenterer r = new Reenterer(s);
        uint256 id = _create(payable(address(r)), 100 ether, 100);
        r.setId(id);
        vm.warp(block.timestamp + 50);
        r.attack();
        assertTrue(r.reentryBlocked());
        assertEq(address(r).balance, 50 ether);           // got exactly what was due once
    }

    function test_CancelInSameBlockRefundsAll() public {
        uint256 id = _create(bob, 100 ether, 100);
        uint256 before = alice.balance;
        vm.prank(alice); s.cancel(id);
        assertEq(alice.balance - before, 100 ether);
        assertEq(s.getWithdrawableAmount(id), 0);
    }

    function test_Reverts() public {
        vm.startPrank(alice);
        vm.expectRevert("ArcStream: zero address");
        s.createStream{value: 1 ether}(payable(address(0)), 100);
        vm.expectRevert("ArcStream: self-stream");
        s.createStream{value: 1 ether}(alice, 100);
        vm.expectRevert("ArcStream: min 60 seconds");
        s.createStream{value: 1 ether}(bob, 59);
        vm.stopPrank();

        uint256 id = _create(bob, 100 ether, 100);
        vm.prank(bob);
        vm.expectRevert("ArcStream: not sender");
        s.cancel(id);
        vm.prank(alice);
        vm.expectRevert("ArcStream: not recipient");
        s.withdraw(id);
        vm.warp(block.timestamp + 100);
        vm.prank(alice);
        vm.expectRevert("ArcStream: stream ended");
        s.cancel(id);
    }

    /// Fuzz: whatever happens, funds are conserved and nothing stays stuck
    function testFuzz_Conservation(uint96 amount, uint32 duration, uint32 t1, uint32 t2) public {
        duration = uint32(bound(duration, 60, 365 days));
        uint256 amt = bound(amount, duration, 500 ether);
        t1 = uint32(bound(t1, 0, uint256(duration) * 2));
        t2 = uint32(bound(t2, 0, uint256(duration) * 2));

        uint256 aliceStart = alice.balance;
        uint256 id = _create(bob, amt, duration);

        vm.warp(block.timestamp + t1);
        if (s.getWithdrawableAmount(id) > 0) { vm.prank(bob); s.withdraw(id); }

        vm.warp(block.timestamp + t2);
        (, , , , , uint256 endTime, , , ) = s.streams(id);
        if (block.timestamp < endTime) { vm.prank(alice); s.cancel(id); }

        if (s.getWithdrawableAmount(id) > 0) { vm.prank(bob); s.withdraw(id); }

        assertEq(address(s).balance, 0);
        assertEq(alice.balance + bob.balance, aliceStart);
    }
}
