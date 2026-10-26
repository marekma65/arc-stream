// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title ArcStream
 * @notice Real-time payment streaming on Arc — streams native USDC per-second
 * @dev Based on OPNStream (IOPn Builders S1). Changes for Arc:
 *      - native sends use call{value:} instead of transfer() (the 2300-gas limit
 *        breaks smart accounts, EIP-7702 wallets and multisigs)
 *      - cancel() refunds only the sender; the recipient's accrued part stays
 *        claimable via withdraw(), so a recipient that cannot receive
 *        (e.g. USDC-blocklisted or a reverting contract) never blocks the refund
 *      - reentrancy guard on all state-changing functions
 *      Function signatures and the Stream struct are unchanged (same ABI).
 * @author wija_
 */
contract ArcStream {

    // ─────────────────────────────────────────────
    //  STRUCTS
    // ─────────────────────────────────────────────

    struct Stream {
        address payable sender;
        address payable recipient;
        uint256 deposit;         // total locked (wei, 18 decimals); after cancel = amount streamed up to cancel
        uint256 ratePerSecond;   // deposit / duration
        uint256 startTime;
        uint256 endTime;         // after cancel = cancel time
        uint256 withdrawn;       // total already withdrawn by recipient
        bool    cancelled;
        bool    exists;
    }

    // ─────────────────────────────────────────────
    //  STATE
    // ─────────────────────────────────────────────

    uint256 public nextStreamId = 1;

    mapping(uint256 => Stream)      public streams;
    mapping(address => uint256[])   public senderStreams;
    mapping(address => uint256[])   public recipientStreams;

    uint256 private _lock = 1;

    // ─────────────────────────────────────────────
    //  EVENTS
    // ─────────────────────────────────────────────

    event StreamCreated(
        uint256 indexed streamId,
        address indexed sender,
        address indexed recipient,
        uint256 deposit,
        uint256 startTime,
        uint256 endTime
    );

    event Withdrawn(
        uint256 indexed streamId,
        address indexed recipient,
        uint256 amount
    );

    event StreamCancelled(
        uint256 indexed streamId,
        uint256 senderRefund,
        uint256 recipientAmount   // left claimable for the recipient via withdraw()
    );

    // ─────────────────────────────────────────────
    //  MODIFIERS
    // ─────────────────────────────────────────────

    modifier nonReentrant() {
        require(_lock == 1, "ArcStream: reentrant call");
        _lock = 2;
        _;
        _lock = 1;
    }

    // ─────────────────────────────────────────────
    //  WRITE
    // ─────────────────────────────────────────────

    /**
     * @notice Create a new payment stream
     * @param recipient Address that will receive streamed USDC
     * @param duration  Stream length in seconds (minimum 60)
     * @return streamId Unique identifier for the stream
     */
    function createStream(
        address payable recipient,
        uint256 duration
    ) external payable nonReentrant returns (uint256 streamId) {
        require(msg.value > 0,                          "ArcStream: deposit required");
        require(recipient != address(0),                "ArcStream: zero address");
        require(recipient != msg.sender,                "ArcStream: self-stream");
        require(duration >= 60,                         "ArcStream: min 60 seconds");
        require(msg.value >= duration,                  "ArcStream: deposit too small");

        streamId = nextStreamId++;

        uint256 ratePerSecond = msg.value / duration;
        // Dust = remainder from integer division, returned to sender
        uint256 dust    = msg.value - (ratePerSecond * duration);
        uint256 deposit = msg.value - dust;

        streams[streamId] = Stream({
            sender:        payable(msg.sender),
            recipient:     recipient,
            deposit:       deposit,
            ratePerSecond: ratePerSecond,
            startTime:     block.timestamp,
            endTime:       block.timestamp + duration,
            withdrawn:     0,
            cancelled:     false,
            exists:        true
        });

        senderStreams[msg.sender].push(streamId);
        recipientStreams[recipient].push(streamId);

        emit StreamCreated(streamId, msg.sender, recipient, deposit, block.timestamp, block.timestamp + duration);

        if (dust > 0) {
            _send(payable(msg.sender), dust);
        }
    }

    /**
     * @notice Withdraw accrued USDC (recipient only).
     *         Also works after cancel, for the part streamed before cancellation.
     */
    function withdraw(uint256 streamId) external nonReentrant {
        Stream storage s = streams[streamId];
        require(s.exists,                   "ArcStream: not found");
        require(msg.sender == s.recipient,  "ArcStream: not recipient");

        uint256 amount = _withdrawable(s);
        require(amount > 0,                 "ArcStream: nothing to withdraw");

        s.withdrawn += amount;

        emit Withdrawn(streamId, msg.sender, amount);

        _send(s.recipient, amount);
    }

    /**
     * @notice Cancel an active stream (sender only).
     *         Sender gets the unstreamed part back immediately.
     *         The part streamed so far stays claimable by the recipient.
     */
    function cancel(uint256 streamId) external nonReentrant {
        Stream storage s = streams[streamId];
        require(s.exists,                    "ArcStream: not found");
        require(msg.sender == s.sender,      "ArcStream: not sender");
        require(!s.cancelled,                "ArcStream: already cancelled");
        require(block.timestamp < s.endTime, "ArcStream: stream ended");

        uint256 streamedNow     = _streamed(s);
        uint256 senderRefund    = s.deposit - streamedNow;
        uint256 recipientAmount = streamedNow - s.withdrawn;

        // Freeze the stream: from now on _streamed() returns streamedNow
        s.cancelled = true;
        s.deposit   = streamedNow;
        s.endTime   = block.timestamp;

        emit StreamCancelled(streamId, senderRefund, recipientAmount);

        if (senderRefund > 0) {
            _send(s.sender, senderRefund);
        }
    }

    // ─────────────────────────────────────────────
    //  READ
    // ─────────────────────────────────────────────

    function getStreamedAmount(uint256 streamId) external view returns (uint256) {
        Stream storage s = streams[streamId];
        require(s.exists, "ArcStream: not found");
        return _streamed(s);
    }

    function getWithdrawableAmount(uint256 streamId) external view returns (uint256) {
        Stream storage s = streams[streamId];
        require(s.exists, "ArcStream: not found");
        return _withdrawable(s);
    }

    function getSenderStreams(address sender) external view returns (uint256[] memory) {
        return senderStreams[sender];
    }

    function getRecipientStreams(address recipient) external view returns (uint256[] memory) {
        return recipientStreams[recipient];
    }

    function getStream(uint256 streamId) external view returns (Stream memory) {
        require(streams[streamId].exists, "ArcStream: not found");
        return streams[streamId];
    }

    // ─────────────────────────────────────────────
    //  INTERNAL
    // ─────────────────────────────────────────────

    function _streamed(Stream storage s) internal view returns (uint256) {
        if (block.timestamp >= s.endTime) {
            return s.deposit;
        }
        uint256 elapsed = block.timestamp - s.startTime;
        return elapsed * s.ratePerSecond;
    }

    function _withdrawable(Stream storage s) internal view returns (uint256) {
        return _streamed(s) - s.withdrawn;
    }

    function _send(address payable to, uint256 amount) internal {
        (bool ok, ) = to.call{value: amount}("");
        require(ok, "ArcStream: transfer failed");
    }
}
