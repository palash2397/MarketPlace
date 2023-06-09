import { Signer } from "@ethersproject/abstract-signer";
import { task } from "hardhat/config";
import { TaskArguments } from "hardhat/types";

import { MarketplaceValidator__factory } from "../../src/types/factories/contracts/utils/ MarketplaceValidator.sol";
import { readContractAddress, writeContractAddress } from "./addresses/utils";

task("deploy:MarketplaceValidator")
  .addParam("signer", "Index of the signer in the metamask address list")
  .setAction(async function (taskArguments: TaskArguments, { ethers, upgrades }) {
    console.log("--- start deploying the Marketplace Validator Contract ---");
    const accounts: Signer[] = await ethers.getSigners();
    const index = Number(taskArguments.signer);

    // Use accounts[1] as the signer for the real roll
    const marketplace: MarketplaceValidator__factory = <MarketplaceValidator__factory>(
      await ethers.getContractFactory("MarketplaceValidator", accounts[index])
    );

    const marketplaceProxy = await upgrades.deployProxy(marketplace);
    await marketplaceProxy.deployed();
    writeContractAddress("MarketplaceValidator", marketplaceProxy.address);
    console.log("Marketplace Validator proxy deployed to: ", marketplaceProxy.address);

    const impl = await upgrades.erc1967.getImplementationAddress(marketplaceProxy.address);
    console.log("Implementation :", impl);
  });

task("upgrade:MarketplaceValidator")
  .addParam("signer", "Index of the signer in the metamask address list")
  .setAction(async function (taskArguments: TaskArguments, { ethers, upgrades }) {
    console.log("--- start upgrading the Marketplace Validator Contract ---");
    const accounts: Signer[] = await ethers.getSigners();
    const index = Number(taskArguments.signer);

    // Use accounts[1] as the signer for the real roll
    const marketplaceProxy: MarketplaceValidator__factory = <MarketplaceValidator__factory>(
      await ethers.getContractFactory("MarketplaceValidator", accounts[index])
    );

    const proxyMarketPlaceAddress = readContractAddress("MarketplaceValidator");

    const upgraded = await upgrades.upgradeProxy(proxyMarketPlaceAddress, marketplaceProxy);

    console.log("Marketplace Validator upgraded to: ", upgraded.address);

    const impl = await upgrades.erc1967.getImplementationAddress(upgraded.address);
    console.log("Implementation :", impl);
  });

task("verify:MarketplaceValidator")
  .addParam("contractAddress", "Input the deployed contract address")
  .setAction(async function (taskArguments: TaskArguments, { run }) {
    await run("verify:verify", {
      address: taskArguments.contractAddress,
      constructorArguments: [],
    });
  });
