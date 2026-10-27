# Arc Stream

Real-time USDC payment streaming on [Arc](https://docs.arc.io), Circle's stablecoin L1.
Lock a USDC deposit, it flows to the recipient every second, they withdraw anytime, and the sender can cancel to get back what hasn't flowed yet.

**Live app:** https://arc-stream-xi.vercel.app

**User guide:** [docs/USER-GUIDE.md](docs/USER-GUIDE.md)

Built by wija_ ([@wija_tools](https://x.com/wija_tools)). Based on [OPN Stream](https://github.com/marekma65/opn-stream) (IOPn Builders Season 1), adapted for Arc.

## Contracts

| Network | Chain ID | ArcStream address | Explorers | Source verification |
|---|---|---|---|---|
| Arc Mainnet | 5042 | [`0xDA6441F518bD8015E3a3d5484B9331c6d29Ca9A9`](https://arc.etherscan.io/address/0xDA6441F518bD8015E3a3d5484B9331c6d29Ca9A9#code) | [Etherscan](https://arc.etherscan.io/address/0xDA6441F518bD8015E3a3d5484B9331c6d29Ca9A9#code) · [Arc Explorer](https://explorer.arc.io/address/0xDA6441F518bD8015E3a3d5484B9331c6d29Ca9A9) | [Sourcify — Exact Match](https://repo.sourcify.dev/5042/0xDA6441F518bD8015E3a3d5484B9331c6d29Ca9A9) |
| Arc Testnet | 5042002 | [`0x76030AC92B85144e372644894c39Fc4550bFf740`](https://explorer.testnet.arc.io/address/0x76030AC92B85144e372644894c39Fc4550bFf740) | [Arc Explorer](https://explorer.testnet.arc.io/address/0x76030AC92B85144e372644894c39Fc4550bFf740) | — |

The mainnet contract is verified on Sourcify with an exact match (runtime and creation bytecode, including metadata), and the verified source is shown on Arc Etherscan. The Arc Explorer (explorer.arc.io) does not yet accept verification submissions, so it may still show the contract as unverified.

## Networks

| Network | Chain ID | RPC | Explorer |
|---|---|---|---|
| Arc Mainnet | 5042 | https://rpc.mainnet.arc.io | https://arc.etherscan.io · https://explorer.arc.io |
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
- `docs/USER-GUIDE.md` — step-by-step guide for users
- `verify/ArcStream-standard-input.json` — exact compiler input used for the deployed bytecode (for source verification)

## Compiler settings

solc 0.8.28+commit.7893614a, optimizer enabled with 200 runs, EVM version cancun, no constructor arguments. Contract identifier in the verification input: `src/ArcStream.sol:ArcStream`.

## License

MIT
