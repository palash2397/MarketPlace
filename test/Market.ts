import { assert, expect } from "chai";
import { BigNumber } from "ethers";

const { ethers } = require("ethers");
const marketPlaceABI = require("./contractABI/market.json");
const validatorABI = require("./contractABI/validator.json");
const nftABI = require("./contractABI/nft.json");

const marketplaceAddress = "0xd11782BB39f1E2E45DC715A837641dfe46380a5d";
const validatorAddress = "0xBA3f264B097286294FFF1673e483cDcc445BAa0C";
const nftAddress = "0x16F6590055Ce9AF9e5b1CEb87217051B61213811";

const privateKey = "fe2d1b12f7cb4f6aaf2953b8d1528bf9ee0329eb1d89f9b380cc595c05475a9d";
const privateKey1 = "582cc47eaf54e26b6b598130eb474583a4cf3c46b11f083613539633bf8687b1";

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

describe("unit test", function () {
  let john: any, chris: any, marketContract: any, validatorContract: any, nftContract: any, provider: any;

  beforeEach("", async () => {
    provider = new ethers.providers.JsonRpcProvider("https://goerli.infura.io/v3/4962f71476f6413589734567fa3d9a2c");

    // Create a wallet using the private key
    john = new ethers.Wallet(privateKey, provider);
    chris = new ethers.Wallet(privateKey1, provider);

    // Create a contract instance
    marketContract = new ethers.Contract(marketplaceAddress, marketPlaceABI, provider);
    validatorContract = new ethers.Contract(validatorAddress, validatorABI, provider);
    nftContract = new ethers.Contract(nftAddress, nftABI, provider);
    // console.log("nftContract --->", nftContract.address);

    await validatorContract.connect(john).setVICNFTAddress(nftContract.address);
  });

    it("it should update time", async () => {
      var tx = await marketContract.connect(john).setClosingTime(600);
      tx.wait();
    });
  it("buy", async () => {
    // var nftTx = await nftContract.connect(john).safeMint(john.address, "image1", john.address, 10);
    // var nftTxn = await nftTx.wait();
    // //  console.log("nftTxn ----->", nftTxn);

    // var events = await nftTxn.events?.filter((e: any) => e.event === "Transfer");
    // var event = events[0];

    // var tokenId = await event.args?.tokenId;

    // console.log("tokenId ---->", tokenId.toNumber());

    let objId = "objId";
    objId = objId.toString();

    let order = [
      john.address,
      nftContract.address,
      10,
      john.address,
      "0x0000000000000000000000000000000000000000",
      BigNumber.from("10000000000000"),
      0,
      0,
      0,
      8,
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
        chainId: 5,
        verifyingContract: validatorContract.address,
      },
      primaryType: "Order",
      message: await getSignPayloadFromListingData(order),
    };
    const signature = await john._signTypedData(
      typedDataMessage.domain,
      typedDataMessage.types,
      typedDataMessage.message,
    );

    order = [
      john.address,
      nftContract.address,
      10,
      john.address,
      "0x0000000000000000000000000000000000000000",
      BigNumber.from("10000000000000"),
      0,
      0,
      0,
      8,
      signature,
      "image1",
      objId,
    ];

    // var tx = await validatorContract._verifyOrderSig(order);
    // console.log("tx ---->", tx);

    var tx = await nftContract.connect(john).ownerOf(8);
    console.log("tx --->", tx);
    await nftContract.connect(john).approve(marketContract.address, 8);

    await validatorContract.connect(john).addPaymentTokens(["0x0000000000000000000000000000000000000000"]);
    console.log("1");
    var tx = await marketContract.connect(chris).buy(nftAddress, 8, BigNumber.from("10000000000000"), order, {
      value: BigNumber.from("10000000000000"),
    });
    await tx.wait();

  // });

  it("lazy minting", async () => {
    let objId = "objId";
    objId = objId.toString();

    let order = [
      chris.address,
      nftContract.address,
      10,
      chris.address,
      "0x0000000000000000000000000000000000000000",
      BigNumber.from("10000000000000"),
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
        chainId: 5,
        verifyingContract: validatorContract.address,
      },
      primaryType: "Order",
      message: await getSignPayloadFromListingData(order),
    };
    const signature = await chris._signTypedData(
      typedDataMessage.domain,
      typedDataMessage.types,
      typedDataMessage.message,
    );

    order = [
      chris.address,
      nftContract.address,
      10,
      chris.address,
      "0x0000000000000000000000000000000000000000",
      BigNumber.from("10000000000000"),
      0,
      0,
      0,
      0,
      signature,
      "image1",
      objId,
    ];

    var tx = await validatorContract._verifyOrderSig(order);
    console.log("tx ---->", tx);

    await validatorContract.connect(john).addPaymentTokens(["0x0000000000000000000000000000000000000000"]);

    var tx = await marketContract.connect(john).buy(nftContract.address, 0, BigNumber.from("10000000000000"), order, {
      value: BigNumber.from("10000000000000"),
    });
    await tx.wait();
  });

  it("WithDraw eth", async () => {

    const tx = await marketContract.connect(john).withdrawETH(john.address);
    const txn = await tx.wait();
    const contractBalanceAfter = await provider.getBalance(marketContract.address);
    expect(contractBalanceAfter).to.equal(0);

  });
});
