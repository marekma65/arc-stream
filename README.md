# Arc Stream

Real-time USDC payment streaming on [Arc](https://docs.arc.io), Circle's stablecoin L1.
Lock a USDC deposit, it flows to the recipient every second, they withdraw anytime, and the sender can cancel to get back what hasn't flowed yet.

Built by wija_ ([@wija_tools](https://x.com/wija_tools)). Based on [OPN Stream](https://github.com/marekma65/opn-stream) (IOPn Builders Season 1), adapted for Arc.

## Networks

| Network | Chain ID | RPC | Explorer |
|---|---|---|---|
| Arc Mainnet | 5042 | https://rpc.mainnet.arc.io | https://explorer.arc.io |
| Arc Testnet | 5042002 | https://rpc.testnet.arc.io | https://explorer.testnet.arc.io |

Gas is paid in USDC (native, 18 decimals).

## Changes vs OPN Stream

- Native sends use `call{value:}` instead of `transfer()`, so smart accounts, EIP-7702 wallets and multisigs can receive.
- `cancel()` refunds only the sender. The recipient's accrued part stays claimable via `withdraw()`, so a recipient that can't receive never blocks the sender's refund.
- Reentrancy guard on all state-changing functions.
- Same function signatures and `Stream` struct as OPN Stream.

## Files

- `contracts/ArcStream.sol` — the contract
- `test/ArcStream.t.sol` — Foundry tests (`forge test`)
- `index.html` — the app (ethers.js v5, no build step)
- `deploy.html` — deploy the contract from your wallet

## Deploy

1. Open `deploy.html`, pick Arc Testnet, connect, deploy.
2. Paste the address into `index.html` → `NETWORKS.arcTestnet.contract`.
3. Test create, withdraw and cancel on testnet.
4. Repeat for Arc Mainnet → `NETWORKS.arc.contract`.

Compiler settings (for explorer verification): solc 0.8.28, optimizer enabled with 200 runs, EVM version cancun, no constructor arguments.

## License

MIT
