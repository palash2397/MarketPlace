import { config as dotenvConfig } from "dotenv";
import { ethers } from "ethers";
import * as fs from "fs";
import * as path from "path";

dotenvConfig({ path: path.resolve(__dirname, "../../../.env") });

console.log("DEPLOY_NETWORK: ", process.env.DEPLOY_NETWORK);
export type FileName = "ClubrareMarketplace" | "MarketplaceValidator";

const network = () => {
  const { DEPLOY_NETWORK } = process.env;
  if (!DEPLOY_NETWORK || DEPLOY_NETWORK === "hardhat") return "rinkeby";
  if (DEPLOY_NETWORK) return DEPLOY_NETWORK;
  return "mainnet";
};

export const writeContractAddress = (contractFileName: FileName, address: string) => {
  const NETWORK = network();

  fs.writeFileSync(
    path.join(__dirname, `${NETWORK}/${contractFileName}.json`),
    JSON.stringify({
      address,
    }),
  );
};

export const readContractAddress = (contractFileName: FileName): string => {
  const NETWORK = network();
  const name = path.join(__dirname, `${NETWORK}/${contractFileName}.json`);

  if (!fs.existsSync(name)) {
    writeContractAddress(contractFileName, ethers.constants.AddressZero);
  }

  const rawData = fs.readFileSync(name);
  const info = JSON.parse(rawData.toString());

  return info.address;
};
