// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

interface IClubrareMarketplace {
    struct Order {
        /* Order maker address. */
        address seller;
        /* contract Address */
        address contractAddress;
        /* Collection Royalty Fee. */
        uint256 royaltyFee;
        /* Royalty receiver once order is completed */
        address royaltyReceiver;
        /* Token used to pay for the order. Only WETH for now */
        address paymentToken;
        /* Base price of the order (in paymentTokens). */
        uint256 basePrice;
        /* Listing timestamp. */
        uint256 listingTime;
        /* Expiration timestamp - 0 for no expiry. */
        uint256 expirationTime;
        /* Order nonce, used to prevent duplicate. */
        uint256 nonce;
        /* Token Id */
        uint256 tokenId;
        /* Signature */
        bytes signature;
        /* metadata URI for Minting*/
        string uri;
        /* Obj Id for internal mapping */
        string objId;
    }

    struct FeeSplit {
        /* address of fee receive*/
        address payee;
        /*percentage of fee spilt*/
        uint256 share;
    }

    event Buy(
        address buyer,
        address seller,
        address contractAddress,
        uint256 tokenId,
        uint256 amount,
        uint256 time,
        address paymentToken,
        string objId
    );

    event CancelOrder(
        address seller,
        address contractAddress,
        uint256 tokenId,
        uint256 amount,
        uint256 time,
        address paymentToken,
        string objId
    );

    event Reckon(uint256 platformFee, address _erc20Token, uint256 royaltyValue, address royaltyReceiver);

    event AdminRemoved(address admin, uint256 time);
    event AdminAdded(address admin, uint256 time);

    event NFTBurned(
        address indexed collection,
        uint256 indexed tokenId,
        address indexed admin,
        uint256 time,
        string tokenURI
    );

    event SetTradeFee(uint256 tradeFee);
    event BlacklistUser(address user);
    event AllowedPaymentToken(address token);
}
