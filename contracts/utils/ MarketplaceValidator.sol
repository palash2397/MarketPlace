// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/draft-EIP712Upgradeable.sol";
import "../interfaces/IClubrareMarketPlace.sol";
import "../interfaces/INFT.sol";
import "../interfaces/IERC20.sol";

contract MarketplaceValidator is
    Initializable,
    IClubrareMarketplace,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    EIP712Upgradeable
{
    // Contract Name
    string public constant name = "Victor Marketplace";
    //Contract Version
    string public constant version = "1.0.1";
    // NOTE: these hashes are derived from keccak("VICTOR_MARKETPLACE_NAME") function
    //and verified in the constructor.
    //Contract Name hash
    bytes32 internal constant _NAME_HASH = 0xf3886df3d4585116dd383bb5b6c6732cd2afec4cbd5f85161b3effde25ef8739;
    //Contract Version Hash
    bytes32 internal constant _VERSION_HASH = 0xfc7f6d936935ae6385924f29da7af79e941070dafe46831a51595892abc1b97a;
    //Order Struct Hash
    bytes32 internal constant _ORDER_TYPEHASH = 0xa3b972f2222c232c40435980697cfe2e1c6f22b2fdb83bf78486c4e45b734e74;

    //Derived Domain Separtor Hash Variable for EIP712 Domain Seprator
    bytes32 internal _domainSeparator;

    /* Blacklisted addresses */
    mapping(address => bool) public blacklist;

    mapping(address => bool) public adminContracts;

    /* Admins addresses */
    mapping(address => bool) public admins;

    /* Allowed ERC20 Payment tokens */
    mapping(address => bool) public allowedPaymenTokens;

    /* makertplace address for admins items */
    address public marketplace;

    address public vicNFTAddress;

    function initialize() external initializer {
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        __EIP712_init(name, version);
        require(keccak256(bytes(name)) == _NAME_HASH, "name hash mismatch");
        require(keccak256(bytes(version)) == _VERSION_HASH, "version hash mismatch");
        require(
            keccak256(
                "Order(address seller,"
                "address contractAddress,"
                "uint256 royaltyFee,"
                "address royaltyReceiver,"
                "address paymentToken,"
                "uint256 basePrice,"
                "uint256 listingTime,"
                "uint256 expirationTime,"
                "uint256 nonce,"
                "uint256 tokenId,"
                "string uri,"
                "string objId)"
            ) == _ORDER_TYPEHASH,
            "order hash mismatch"
        );

        _domainSeparator = _domainSeparatorV4();
    }

    /**
     * @dev Blacklist addresses to disable their trading
     */
    function excludeAddresses(address[] calldata _users) external onlyOwner {
        for (uint256 i = 0; i < _users.length; i++) {
            blacklist[_users[i]] = true;
            emit BlacklistUser(_users[i]);
        }
    }

    function setVICNFTAddress(address _vicNft) external onlyOwner {
        vicNFTAddress = _vicNft;
    }

    /**
     * @dev Add payment tokens to trade
     */
    function addPaymentTokens(address[] calldata _tokens) external onlyOwner {
        for (uint256 i = 0; i < _tokens.length; i++) {
            allowedPaymenTokens[_tokens[i]] = true;
            emit AllowedPaymentToken(_tokens[i]);
        }
    }

    function setMarketplaceAddress(address _marketplace) external onlyOwner {
        marketplace = _marketplace;
    }

    /**
     * @notice This function is used to add address of admins
     * @dev Fuction take address type argument
     * @param admin The account address of admin
     */
    function addAdmin(address admin) public onlyOwner {
        require(!admins[admin], "admin already in list");
        admins[admin] = true;
        emit AdminAdded(admin, block.timestamp);
    }

    /**
     * @notice This function is used to get list of all address of admins
     * @dev This Fuction is not take any argument
     * @param admin The account address of admin
     */
    function removeAdmin(address admin) public onlyOwner {
        require(admins[admin], "not a admin");
        admins[admin] = false;
        emit AdminRemoved(admin, block.timestamp);
    }

    function isNFTHolder(address contractAddress, address user) public view returns (bool) {
        return INFT(contractAddress).balanceOf(user) > 0;
    }

    function verifySeller(Order calldata order, address _user) public view returns (bool) {
        (, address signer) = _verifyOrderSig(order);
        return admins[signer] ? admins[_user] : signer == _user;
    }

    function _verifyOrderSig(Order calldata order) public view returns (bytes32, address) {
        bytes32 digest = hashToSign(order);
        address signer = ECDSAUpgradeable.recover(digest, order.signature);
        return (digest, signer);
    }

    /**
     * @dev Validate a provided previously approved / signed order, hash, and signature.
     * @param order Order to validate
     */
    function validateOrder(Order calldata order) public view returns (bool validated) {
        /* Not done in an if-conditional to prevent unnecessary ecrecover 
        evaluation, which seems to happen even though it should short-circuit. */
        (, address signer) = _verifyOrderSig(order);
        /* Order must have valid parameters. */
        if (!validateOrderParameters(order)) {
            return false;
        }

        /* recover via ECDSA, signed by seller (already verified as non-zero). */
        if (admins[signer] ? marketplace == order.seller : signer == order.seller) {
            return true;
        }
    }

    /**
     * @dev Validate order parameters (does *not* check signature validity)
     * @param order Order to validate
     */
    function validateOrderParameters(Order memory order) internal pure returns (bool) {
        /* Order must have a maker. */
        if (order.seller == address(0)) {
            return false;
        }

        if (order.basePrice <= 0) {
            return false;
        }

        if (order.contractAddress == address(0)) {
            return false;
        }

        return true;
    }

    function hashOrder(Order memory _order) public pure returns (bytes32 hash) {
        bytes memory array = bytes.concat(
            abi.encode(
                _ORDER_TYPEHASH,
                _order.seller,
                _order.contractAddress,
                _order.royaltyFee,
                _order.royaltyReceiver,
                _order.paymentToken,
                _order.basePrice,
                _order.listingTime
            ),
            abi.encode(
                _order.expirationTime,
                _order.nonce,
                _order.tokenId,
                keccak256(bytes(_order.uri)),
                keccak256(bytes(_order.objId))
            )
        );
        hash = keccak256(array);
        return hash;
    }

    /**
     * @dev Hash an order, returning the hash that a client must sign via EIP-712 including the message prefix
     * @param order Order to hash
     * @return Hash of message prefix and order hash per Ethereum format
     */
    function hashToSign(Order memory order) public view returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", _domainSeparator, hashOrder(order)));
    }
}
