import { Signer } from "@ethersproject/abstract-signer";
import { task } from "hardhat/config";
import { TaskArguments } from "hardhat/types";

import { ClubrareMarketplace__factory } from "../../src/types";
import { readContractAddress, writeContractAddress } from "./addresses/utils";
import values from "./arguments/marketplace";

task("deploy:ClubrareMarketplace")
  .addParam("signer", "Index of the signer in the metamask address list")
  .setAction(async function (taskArguments: TaskArguments, { ethers, upgrades }) {
    console.log("--- start deploying the Clubrare Marketplace Contract ---");
    const accounts: Signer[] = await ethers.getSigners();
    const index = Number(taskArguments.signer);

    // Use accounts[1] as the signer for the real roll
    const marketplace: ClubrareMarketplace__factory = <ClubrareMarketplace__factory>(
      await ethers.getContractFactory("ClubrareMarketplace", accounts[index])
    );

    const marketplaceProxy = await upgrades.deployProxy(marketplace, [values.VALIDATOR, values.FEE_SPLIT]);
    await marketplaceProxy.deployed();
    writeContractAddress("ClubrareMarketplace", marketplaceProxy.address);
    console.log("Clubrare Marketplace proxy deployed to: ", marketplaceProxy.address);

    const impl = await upgrades.erc1967.getImplementationAddress(marketplaceProxy.address);
    console.log("Implementation :", impl);
  });

task("upgrade:ClubrareMarketplace")
  .addParam("signer", "Index of the signer in the metamask address list")
  .setAction(async function (taskArguments: TaskArguments, { ethers, upgrades }) {
    console.log("--- start upgrading the Clubrare Marketplace Contract ---");
    const accounts: Signer[] = await ethers.getSigners();
    const index = Number(taskArguments.signer);

    // Use accounts[1] as the signer for the real roll
    const marketplaceProxy: ClubrareMarketplace__factory = <ClubrareMarketplace__factory>(
      await ethers.getContractFactory("ClubrareMarketplace", accounts[index])
    );

    const proxyMarketPlaceAddress = readContractAddress("ClubrareMarketplace");

    const upgraded = await upgrades.upgradeProxy(proxyMarketPlaceAddress, marketplaceProxy);

    console.log("Clubrare Marketplace upgraded to: ", upgraded.address);

    const impl = await upgrades.erc1967.getImplementationAddress(upgraded.address);
    console.log("Implementation :", impl);
  });

task("verify:ClubrareMarketplace")
  .addParam("contractAddress", "Input the deployed contract address")
  .setAction(async function (taskArguments: TaskArguments, { run }) {
    await run("verify:verify", {
      address: taskArguments.contractAddress,
      constructorArguments: [],
    });
  });
