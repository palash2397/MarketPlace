import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address.js";
import { assert, expect } from "chai";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";
import { upgrades } from "hardhat";

function getSignPayloadFromListingData(order: any) {
  const [
    collectibleOwner,
    contractAddress,
    royalty,
    creatorAddress,
    paymentTokenType,
    price,
    startTime,
    endTime,
    nonce,
    tokenId,
    signature,
    uri,
    objId,
  ] = order;
  return {
    basePrice: BigNumber.from(price),
    contractAddress: contractAddress,
    expirationTime: BigNumber.from(endTime),
    listingTime: BigNumber.from(startTime),
    nonce,
    objId: objId,
    paymentToken: paymentTokenType,
    royaltyFee: BigNumber.from(royalty),
    royaltyReceiver: creatorAddress,
    seller: collectibleOwner,
    tokenId: BigNumber.from(tokenId),
    uri: uri,
  };
}
describe("Unit Tests", function () {
  let validator: any,
    marketPlace: any,
    admin: SignerWithAddress,
    chris: SignerWithAddress,
    john: SignerWithAddress,
    token: any,
    nft: any;

  beforeEach(async () => {
    const signers: SignerWithAddress[] = await ethers.getSigners();
    admin = signers[0];
    chris = signers[1];
    john = signers[2];

    const Validator = await ethers.getContractFactory("MarketplaceValidator");
    validator = await upgrades.deployProxy(Validator, { initializer: "initialize" });
    await validator.deployed();

    const NFT = await ethers.getContractFactory("NFT");
    nft = await NFT.deploy("contractURI", "BaseURI/");

    const Token = await ethers.getContractFactory("VICToken");
    token = await Token.deploy();
    await token.deployed();
    await token.initialize();

    const market = await ethers.getContractFactory("Marketplace");
    let feeSplit = [[admin.address, 1000]];
    marketPlace = await upgrades.deployProxy(market, [validator.address, feeSplit], { initializer: "initialize" });
    await marketPlace.deployed();

    await validator.setMarketplaceAddress(marketPlace.address);
    await validator.setVICNFTAddress(nft.address);
  });
  it("it should update closing time", async () => {
    var tx = await marketPlace.setClosingTime(600);
    tx.wait();
  });

  it("buy", async () => {
    await nft.connect(john).safeMint(john.address, "image1", john.address, 10);
    let objId = "objId";
    objId = objId.toString();
    let order = [
      john.address,
      nft.address,
      10,
      john.address,
      "0x0000000000000000000000000000000000000000",
      BigNumber.from("10000000000000000000"),
      0,
      0,
      0,
      1,
      "0x0000000000000000000000000000000000000000000000000000000000000000",
      "image1",
      objId,
    ];

    const typedDataMessage = {
      types: {
        Order: [
          { name: "seller", type: "address" },
          { name: "contractAddress", type: "address" },
          { name: "royaltyFee", type: "uint256" },
          { name: "royaltyReceiver", type: "address" },
          { name: "paymentToken", type: "address" },
          { name: "basePrice", type: "uint256" },
          { name: "listingTime", type: "uint256" },
          { name: "expirationTime", type: "uint256" },
          { name: "nonce", type: "uint256" },
          { name: "tokenId", type: "uint256" },
          { name: "uri", type: "string" },
          { name: "objId", type: "string" },
        ],
      },
      domain: {
        name: "Victor Marketplace",
        version: "1.0.1",
        chainId: 31337,
        verifyingContract: validator.address,
      },
      primaryType: "Order",
      message: await getSignPayloadFromListingData(order),
    };
    const signature = await john._signTypedData(
      typedDataMessage.domain,
      typedDataMessage.types,
      typedDataMessage.message,
    );
    //  console.log("signature ---- >", signature);
    order = [
      john.address,
      nft.address,
      10,
      john.address,
      "0x0000000000000000000000000000000000000000",
      BigNumber.from("10000000000000000000"),
      0,
      0,
      0,
      1,
      signature,
      "image1",
      objId,
    ];
    // console.log("john", john.address);
    // console.log("nft address ---->", nft.address);
    // console.log("signature --->", signature);

    let nftPrice = order[5];

    const royaltyFeeCalculations = ((nftPrice * 10) / 10000).toString(); // royaltyAmount = (value (10 ETH) * royalties.amount ( % of royality)) / 10000
    const platformFeeCalculations = ((1000 * nftPrice) / 10000).toString(); // (feeSplits[i].share(/*percentage of fee spilt*/) * _amount (10 ETH)) / FEE_DENOMINATOR (10000)

    await validator.addPaymentTokens(["0x0000000000000000000000000000000000000000"]);
    await token.transfer(chris.address, 100);
    await token.connect(chris).approve(marketPlace.address, 100);
    await nft.connect(john).approve(marketPlace.address, 1);
    const balanceBefore = await ethers.provider.getBalance(john.address);
    var tx = await marketPlace.connect(chris).buy(nft.address, 1, BigNumber.from("10000000000000000000"), order, {
      value: BigNumber.from("10000000000000000000"),
    });
    var txn = await tx.wait();

    // var tx1 = await validator._verifyOrderSig(order);
    // console.log("");

    const balanceAfter = await ethers.provider.getBalance(john.address);
    const differenceOfBalance = balanceAfter.sub(balanceBefore);

    // Retrieve Reckon event
    var events = await txn.events?.filter((e: any) => e.event === "Reckon");
    var event = events[0];

    var royaltyFee = await event.args?.royaltyValue;
    var platformFee = await event.args?.platformFee;

    expect(BigNumber.from(royaltyFeeCalculations)).to.equal(royaltyFee);
    expect(BigNumber.from(platformFeeCalculations)).to.equal(platformFee);
    expect(differenceOfBalance.add(BigNumber.from(platformFee))).to.equal(nftPrice);
  });

  it("WithDraw eth", async () => {
    // Send ETH to the contract
    const amountToSend = ethers.utils.parseEther("1"); // Sending 1 ETH
    await john.sendTransaction({
      to: marketPlace.address,
      value: amountToSend,
    });

    const contractBalanceBefore = await ethers.provider.getBalance(marketPlace.address);
    const tx = await marketPlace.withdrawETH(admin.address);
    const txn = await tx.wait();
    const contractBalanceAfter = await ethers.provider.getBalance(marketPlace.address);

    expect(contractBalanceBefore).to.equal(amountToSend);
    expect(contractBalanceAfter).to.equal(0);
  });
  it("WithDraw token ", async () => {
    await token.transfer(marketPlace.address, 100);
    await validator.addPaymentTokens([token.address]);
    const contractBalanceBefore = await token.balanceOf(marketPlace.address);
    await marketPlace.withdrawToken(john.address, token.address);
    const adminBalance = await token.balanceOf(john.address);
    expect(contractBalanceBefore).to.equal(adminBalance);
  });

  it("lazy minting", async () => {
    let objId = "objId";
    objId = objId.toString();
    let order = [
      john.address,
      nft.address,
      10,
      admin.address,
      "0x0000000000000000000000000000000000000000",
      100,
      0,
      0,
      0,
      0,
      "0x0000000000000000000000000000000000000000000000000000000000000000",
      "image1",
      objId,
    ];

    const typedDataMessage = {
      types: {
        Order: [
          { name: "seller", type: "address" },
          { name: "contractAddress", type: "address" },
          { name: "royaltyFee", type: "uint256" },
          { name: "royaltyReceiver", type: "address" },
          { name: "paymentToken", type: "address" },
          { name: "basePrice", type: "uint256" },
          { name: "listingTime", type: "uint256" },
          { name: "expirationTime", type: "uint256" },
          { name: "nonce", type: "uint256" },
          { name: "tokenId", type: "uint256" },
          { name: "uri", type: "string" },
          { name: "objId", type: "string" },
        ],
      },
      domain: {
        name: "Victor Marketplace",
        version: "1.0.1",
        chainId: 31337,
        verifyingContract: validator.address,
      },
      primaryType: "Order",
      message: await getSignPayloadFromListingData(order),
    };

    const signature = await john._signTypedData(
      typedDataMessage.domain,
      typedDataMessage.types,
      typedDataMessage.message,
    );
    //  console.log("signature ---- >", signature);
    order = [
      john.address,
      nft.address,
      10,
      admin.address,
      "0x0000000000000000000000000000000000000000",
      100,
      0,
      0,
      0,
      0,
      signature,
      "image1",
      objId,
    ];

    await validator.addPaymentTokens(["0x0000000000000000000000000000000000000000"]);
    await token.transfer(chris.address, 1000);
    await token.connect(chris).approve(marketPlace.address, 100);
    var tx = await marketPlace.connect(chris).buy(nft.address, 0, 100, order, { value: 10 });
    var txn = tx.wait();
  });
});
