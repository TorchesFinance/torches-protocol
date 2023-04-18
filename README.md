Torches Protocol
=================

The Torches Protocol is an decentralized non-custodial liquidity protocol based on KCC, where users, wallets and dapps can participate as depositors or borrowers. Depositors provide liquidity to the market to earn a passive income, while borrowers are able to borrow in an over-collateralised manner.

Installation
------------

```
git clone https://github.com/TorchesFinance/torches-protocol/
cd torches-protocol
pnpm install # or `yarn install`
```

Setup
------------

### .env
Copy `.env` from `.env.example`
abd fill in all the variables in `.env`

### hardhat.config.ts
Modify `namedAccounts` in `hardhat.config.ts` and add networks if necessary.

Deployment
------------

```
npx hardhat deploy --network <NETWORK>
```
