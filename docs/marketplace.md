# Ethereum Deployment Steps:

### 1. Setup Environment

- Make sure `.env` is set for the `mainnet` or `goerli` deployment

- `yarn`

- `yarn clean`

- `yarn compile`

### 2. Deploy `Validator` contract

- Set `DEPLOY_NETWORK` to `goerli`or `mainnet`

- Run command ` npx hardhat run --network "network name" tasks/deploy/validator.ts`

- Run command `npx hardhat verify --network "network name" [impl-address]`

### 3. Upgrade `Validator` contract

- Run command ` npx hardhat run --network "network name" tasks/deploy/validatorUpgradable.ts`

- Run command `npx hardhat verify --network "network name" [impl-address]`

### 4. Deploy `ClubrareMarketPlace` contract

- Set `DEPLOY_NETWORK` to `goerli`or `mainnet`

- Run command ` npx hardhat run --network "network name" tasks/deploy/market.ts`

- Run command `npx hardhat verify --network "network name" [impl-address]`

### 5. Upgrade `ClubrareMarketPlace` contract

- Set `DEPLOY_NETWORK` to `goerli`or `mainnet`

- Run command ` npx hardhat run --network "network name" tasks/deploy/marketUpgradable.ts`

- Run command `npx hardhat verify --network "network name" [impl-address]`

### Testing `ClubrareMarketPlace` contract

- Run command `npx hardhat test test/MarketPlace.ts`
![1](https://github.com/blockative/Victor_buynow/assets/118180094/50140cf8-7e90-43a6-a5f3-64cb2b45041d)
![2](https://github.com/blockative/Victor_buynow/assets/118180094/8eaf74ab-8c84-412a-936f-0a70a8d84812)


