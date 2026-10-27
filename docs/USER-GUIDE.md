# Arc Stream — User Guide

Arc Stream lets you pay someone in USDC **by the second**. You lock a USDC amount in a smart contract on Arc, and it flows to the recipient every second for the time you choose. The recipient can withdraw whatever has flowed at any moment, and you can cancel before the end to get back what hasn't flowed yet.

**App:** https://arc-stream-xi.vercel.app

**Source code:** https://github.com/marekma65/arc-stream

No account, no sign-up. You only need a crypto wallet.

---

## 1. What you need

- A browser wallet: **MetaMask**, **Rabby** or **OKX Wallet**.
- **USDC on Arc.** On Arc, USDC is also the gas token, so every transaction fee is paid in USDC. Keep a small extra amount in your wallet for fees.
- For practice: free test USDC on **Arc Testnet** from **https://faucet.circle.com**.

## 2. First connection

1. Open **https://arc-stream-xi.vercel.app**.
2. Click **Connect wallet** (top right) and approve the connection in your wallet.
3. In the network switch next to it, choose:
   - **Testnet** — to try things out with free test USDC,
   - **Mainnet** — to send real USDC.
4. Your wallet will ask to switch (or add) the Arc network. Approve it.
5. Go to the **New stream** tab. Under the Amount field you'll see your **Balance** in USDC.

> Tip: try every new scenario on **Testnet** first. It costs nothing.

## 3. Sending a stream (sender)

1. Open the **New stream** tab.
2. **Recipient address** — paste the address of the person who should receive the money. It must be different from your own address.
3. **Amount** — the total USDC you want to pay, e.g. `10`.
4. **Duration** — how long the money should flow. Click a preset (**1 hour**, **1 day**, **7 days**, **30 days**) or type a number of seconds (minimum 60).
5. Check the summary:
   - **Per second** and **Per day** — the payment rate,
   - **Ends** — when the stream finishes,
   - **You lock** — the amount that leaves your wallet now.
6. Click **Start stream** and confirm the transaction in your wallet.
7. The app switches to **My streams → Sending**. You'll see your stream card with a counter that grows every second.

From now on the amount is held by the contract and flows to the recipient second by second until the end time.

## 4. Receiving money (recipient)

1. The recipient opens the same app and connects **their own** wallet on the **same network** (Testnet or Mainnet).
2. They open **My streams → Receiving**.
3. The stream card shows a green **Withdraw … USDC** button. The amount on the button is everything that has already flowed and hasn't been withdrawn yet.
4. Click **Withdraw** and confirm in the wallet. The USDC arrives in the recipient's wallet.

You can withdraw as often as you like — every hour, once a day, or only after the stream ends. Each withdrawal takes everything that has flowed up to that moment. The recipient needs a little USDC in their wallet to pay the transaction fee.

## 5. Cancelling a stream (sender)

1. Open **My streams → Sending**.
2. On an active stream, click **Cancel stream**, confirm the dialog on the page, then confirm the transaction in your wallet.
3. What happens:
   - **you get back immediately** the part that **has not flowed yet**,
   - the part that **has already flowed stays with the recipient** — they can withdraw it any time in **My streams → Receiving**.

You can only cancel before the stream ends. After the end, the whole amount belongs to the recipient.

## 6. Stream statuses

| Status | Meaning |
|---|---|
| **Flowing** (green) | The stream is running and money is flowing. |
| **Finished** (blue) | Time is up. The whole amount belongs to the recipient. |
| **Cancelled** (red) | The sender cancelled. The recipient can still withdraw the part that flowed before cancellation. |

On each card you'll also see: **Total**, **Per day**, **Withdrawn**, the end (or cancellation) time and, for active streams, **Time left**.

## 7. Good practices

- **Double-check the recipient address.** If you send to a wrong address, cancelling returns only the part that hasn't flowed yet.
- **Keep a few cents of USDC for fees.** Every action (start, withdraw, cancel) is a transaction.
- **If something doesn't update,** press **Ctrl + F5**. The app always reads the current state from the contract.
- **Testnet and Mainnet are separate.** Streams created on Testnet are not visible on Mainnet and vice versa.

## 8. FAQ

**Who holds the money during a stream?**
The smart contract on Arc — not the app's author and not any company. Only the recipient can withdraw the streamed part, and only the sender can cancel and take back the unstreamed part.

**What if the recipient's wallet can't receive funds?**
Your cancellation still works. The contract sends you your refund, and the recipient's part waits in the contract until they can withdraw it.

**Can I see the contract code?**
Yes. The code is open source and verified:
- Sourcify (exact match): https://repo.sourcify.dev/5042/0xDA6441F518bD8015E3a3d5484B9331c6d29Ca9A9
- Arc Etherscan: https://arc.etherscan.io/address/0xDA6441F518bD8015E3a3d5484B9331c6d29Ca9A9#code

**Contract addresses**

| Network | Chain ID | Contract |
|---|---|---|
| Arc Mainnet | 5042 | `0xDA6441F518bD8015E3a3d5484B9331c6d29Ca9A9` |
| Arc Testnet | 5042002 | `0x76030AC92B85144e372644894c39Fc4550bFf740` |

---

Built by wija_ · X / LinkedIn: @wija_tools
