//  ________  ___       ___  ___  ________  ________  ________  ________  _______
// |\   ____\|\  \     |\  \|\  \|\   __  \|\   __  \|\   __  \|\   __  \|\  ___ \
// \ \  \___|\ \  \    \ \  \\\  \ \  \|\ /\ \  \|\  \ \  \|\  \ \  \|\  \ \   __/|
//  \ \  \    \ \  \    \ \  \\\  \ \   __  \ \   _  _\ \   __  \ \   _  _\ \  \_|/__
//   \ \  \____\ \  \____\ \  \\\  \ \  \|\  \ \  \\  \\ \  \ \  \ \  \\  \\ \  \_|\ \
//    \ \_______\ \_______\ \_______\ \_______\ \__\\ _\\ \__\ \__\ \__\\ _\\ \_______\
//     \|_______|\|_______|\|_______|\|_______|\|__|\|__|\|__|\|__|\|__|\|__|\|_______|
//
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/draft-EIP712Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "./utils/ MarketplaceValidator.sol";
import "./interfaces/INFT.sol";
import "./interfaces/IClubrareMarketPlace.sol";

/**
 * @title ClubrareMarketplace contract
 * @notice NFT marketplace contract for Digital and Physical NFTs Clubrare.
 */
contract ClubrareMarketplace is
    Initializable,
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    EIP712Upgradeable,
    ERC721HolderUpgradeable,
    IClubrareMarketplace
{
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using CountersUpgradeable for CountersUpgradeable.Counter;

    MarketplaceValidator internal validator;

    uint256 public updateClosingTime;
    //Order Nonce For Seller
    mapping(address => CountersUpgradeable.Counter) internal _orderNonces;

    /* Cancelled / finalized orders, by hash. */
    mapping(bytes32 => bool) public cancelledOrFinalized;

    /* Fee denomiator that can be used to calculate %. 100% = 10000 */
    uint16 public constant FEE_DENOMINATOR = 10000;

    //fee Spilt array
    FeeSplit[] public feeSplits;

    function initialize(address _validator, FeeSplit[] calldata _feeSplits) external initializer {
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        validator = MarketplaceValidator(_validator);
        _setFeeSplit(_feeSplits, false);
        updateClosingTime = 600;
    }

    function updateParam(address _validator, FeeSplit[] calldata _feeSplits) external onlyOwner {
        validator = MarketplaceValidator(_validator);
        _setFeeSplit(_feeSplits, true);
    }

    modifier adminOrOwnerOnly(address contractAddress, uint256 tokenId) {
        require(
            (msg.sender == IERC721Upgradeable(contractAddress).ownerOf(tokenId)),
            "AdminManager: admin and owner only."
        );
        _;
    }

    modifier isAllowedToken(address contractAddress) {
        require(validator.allowedPaymenTokens(contractAddress), "Invalid Payment token");
        _;
    }

    modifier isNotBlacklisted(address user) {
        require(!validator.blacklist(user), "Access Denied");
        _;
    }

    modifier onlySeller(Order calldata order) {
        require(validator.verifySeller(order, msg.sender), "Not a seller");
        _;
    }

    function setClosingTime(uint256 _second) external onlyOwner {
        updateClosingTime = _second;
    }

    function getCurrentOrderNonce(address owner) public view returns (uint256) {
        return _orderNonces[owner].current();
    }

    function hashOrder(Order memory _order) external view whenNotPaused returns (bytes32 hash) {
        return validator.hashOrder(_order);
    }

    function _isLazyMint(uint256 _tokenId, address _contractAddress) internal view returns (bool) {
        return ((_tokenId == 0 && validator.vicNFTAddress() == _contractAddress));
    }

    function isValidTransfer(address buyer, address seller) private pure {
        require(buyer != seller, "invalid token transfer");
    }

    function _setFeeSplit(FeeSplit[] calldata _feeSplits, bool isUpdate) internal {
        uint256 len = _feeSplits.length;
        for (uint256 i; i < len; i++) {
            if (_feeSplits[i].payee != address(0) && _feeSplits[i].share > 0) {
                if (isUpdate) {
                    feeSplits[i] = _feeSplits[i];
                } else {
                    feeSplits.push(_feeSplits[i]);
                }
            }
        }
    }

    function resetFeeSplit(FeeSplit[] calldata _feeSplits) external onlyOwner {
        delete feeSplits;
        _setFeeSplit(_feeSplits, false);
    }

    // =================== Owner operations ===================

    /**
     * @dev Pause trading
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpause trading
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    function buy(
        address contractAddress,
        uint256 tokenId,
        uint256 amount,
        Order calldata order
    ) external payable whenNotPaused nonReentrant isAllowedToken(order.paymentToken) isNotBlacklisted(msg.sender) {
        // require(!validator.onAuction(order.expirationTime), "item on auction");
        // validator.checkTokenGate(order, msg.sender);
        (, uint256 paid) = _validate(order, amount);
        Order calldata _order = order;
        INFT nftContract = INFT(contractAddress);
        uint256 _tokenId = tokenId;
        if (_isLazyMint(_tokenId, _order.contractAddress)) {
            // mint if not Minted

            nftContract.safeMint(msg.sender, _order.uri, _order.royaltyReceiver, _order.royaltyFee);
        } else {
            isValidTransfer(msg.sender, nftContract.ownerOf(_tokenId));
        }

        _settlement(nftContract, _tokenId, paid, msg.sender, _order);

        emit Buy(
            msg.sender,
            _order.seller,
            _order.contractAddress,
            _tokenId,
            paid,
            block.timestamp,
            _order.paymentToken,
            _order.objId
        );
    }

    function _validate(Order calldata order, uint256 amount) internal returns (address, uint256) {
        (bytes32 digest, address signer) = validator._verifyOrderSig(order);
        require(!cancelledOrFinalized[digest], "signature already invalidated");
        bool isToken = order.paymentToken == address(0) ? false : true;
        uint256 paid = isToken ? amount : msg.value;
        require(paid > 0, "invalid amount");
        require(validator.validateOrder(order), "Invalid Order");
        return (signer, paid);
    }

    function _settlement(
        INFT nftContract,
        uint256 _tokenId,
        uint256 amt,
        address taker,
        Order calldata _order
    ) internal returns (uint256) {
        (address creator, uint256 royaltyAmt) = _getRoyalties(nftContract, _tokenId, amt);
        require(royaltyAmt < amt, "invalid royalty fee");
        uint256 sellerEarning = _chargeAndSplit(amt, taker, _order.paymentToken, royaltyAmt, creator);
        _executeExchange(_order, _order.seller, taker, sellerEarning, _tokenId);
        return sellerEarning;
    }

    //Platform Fee Split
    function _splitFee(
        address user,
        uint256 _amount,
        address _erc20Token
    ) internal returns (uint256) {
        bool isToken = _erc20Token != address(0);
        uint256 _platformFee;
        uint256 len = feeSplits.length;
        for (uint256 i; i < len; i++) {
            uint256 commission = (feeSplits[i].share * _amount) / FEE_DENOMINATOR;
            address payee = feeSplits[i].payee;
            if (isToken) {
                IERC20Upgradeable(_erc20Token).safeTransferFrom(user, payee, commission);
            } else {
                payable(payee).transfer(commission);
            }
            _platformFee += commission;
        }
        return _platformFee;
    }

    //Internal function to distribute commission and royalties
    function _chargeAndSplit(
        uint256 _amount,
        address user,
        address _erc20Token,
        uint256 royaltyValue,
        address royaltyReceiver
    ) internal returns (uint256) {
        uint256 amt = _amount;

        address _token = _erc20Token;
        bool isEth = _checkEth(_token);
        address _user = user;
        address sender = _getTransferUser(_token, _user);
        IERC20Upgradeable ptoken = IERC20Upgradeable(_token);

        uint256 platformFee;
        uint256 _royaltyValue = royaltyValue;
        address _royaltyReceiver = royaltyReceiver;

        if (isEth) {
            payable(_royaltyReceiver).transfer(_royaltyValue);
            platformFee = _splitFee(sender, amt, _token);
        } else {
            ptoken.safeTransferFrom(sender, _royaltyReceiver, _royaltyValue);

            platformFee = _splitFee(sender, amt, _token);
        }

        emit Reckon(platformFee, _token, _royaltyValue, _royaltyReceiver);
        return amt - (platformFee + _royaltyValue);
    }

    function _getTransferUser(address _token, address user) private view returns (address) {
        return _token == address(0) ? address(this) : user;
    }

    function _getRoyalties(
        INFT nft,
        uint256 tokenId,
        uint256 amount
    ) internal view returns (address, uint256) {
        try nft.royaltyInfo(tokenId, amount) returns (address royaltyReceiver, uint256 royaltyAmt) {
            return (royaltyReceiver, royaltyAmt);
        } catch {
            return (address(0), 0);
        }
    }

    function _checkEth(address _token) private pure returns (bool) {
        return _token == address(0) ? true : false;
    }

    function invalidateSignedOrder(Order calldata order) external whenNotPaused nonReentrant {
        (bytes32 digest, address signer) = validator._verifyOrderSig(order);
        require(!cancelledOrFinalized[digest], "signature already invalidated");
        bool isAdmin = validator.admins(msg.sender);
        require(isAdmin ? order.seller == address(this) : msg.sender == signer, "Not a signer");
        cancelledOrFinalized[digest] = true;
        _orderNonces[isAdmin ? address(this) : signer].increment();
        emit CancelOrder(
            order.seller,
            order.contractAddress,
            order.tokenId,
            order.basePrice,
            block.timestamp,
            order.paymentToken,
            order.objId
        );
    }

    //Bulk cancel Order
    function invalidateSignedBulkOrder(Order[] calldata _order) external whenNotPaused nonReentrant {
        address _signer;
        bool isAdmin;
        uint256 len = _order.length;
        for (uint256 i; i < len; i++) {
            Order calldata order = _order[i];
            (bytes32 digest, address signer) = validator._verifyOrderSig(order);
            isAdmin = validator.admins(msg.sender);
            require(isAdmin ? order.seller == address(this) : msg.sender == signer, "Not a signer");
            _signer = signer;
            cancelledOrFinalized[digest] = true;
            emit CancelOrder(
                order.seller,
                order.contractAddress,
                order.tokenId,
                order.basePrice,
                block.timestamp,
                order.paymentToken,
                order.objId
            );
        }
        _orderNonces[isAdmin ? address(this) : _signer].increment();
    }

    function withdrawETH(address admin) external onlyOwner {
        payable(admin).transfer(address(this).balance);
    }

    function withdrawToken(address admin, address _paymentToken) external onlyOwner isAllowedToken(_paymentToken) {
        IERC20Upgradeable token = IERC20Upgradeable(_paymentToken);
        uint256 amount = token.balanceOf(address(this));
        token.safeTransfer(admin, amount);
    }

    function _executeExchange(
        Order calldata order,
        address seller,
        address buyer,
        uint256 _amount,
        uint256 _tokenId
    ) internal {
        _invalidateSignedOrder(order);

        bool isToken = order.paymentToken == address(0) ? false : true; // if native currency or not

        // LazyMinting conditions
        // for admin we have to transfer
        // for user we don't have to transfer because its aleady minted direct to buyer
        if (!_isLazyMint(order.tokenId, order.contractAddress)) {
            IERC721Upgradeable token = IERC721Upgradeable(order.contractAddress);
            token.safeTransferFrom(token.ownerOf(_tokenId), buyer, _tokenId);
        }
        if (isToken) {
            IERC20Upgradeable(order.paymentToken).safeTransferFrom(buyer, seller, _amount);
        } else {
            payable(seller).transfer(_amount);
        }
    }

    function _invalidateSignedOrder(Order calldata order) internal {
        (bytes32 digest, address signer) = validator._verifyOrderSig(order);
        require(!cancelledOrFinalized[digest], "signature already invalidated");
        cancelledOrFinalized[digest] = true;
        _orderNonces[signer].increment();
    }

    function _isMinted(address contractAddress, uint256 tokenId) private view returns (bool) {
        try IERC721Upgradeable(contractAddress).ownerOf(tokenId) returns (address) {
            return true;
        } catch {
            return false;
        }
    }

    /**
     * @notice This function is used to burn the apporved NFTToken to
     * certain admin address which was allowed by super admin the owner of Admin Manager
     * @dev This Fuction is take two arguments address of contract and tokenId of NFT
     * @param collection tokenId The contract address of NFT contract and tokenId of NFT
     */
    function burnNFT(address collection, uint256 tokenId) external adminOrOwnerOnly(collection, tokenId) {
        INFT nftContract = INFT(collection);

        string memory tokenURI = nftContract.tokenURI(tokenId);
        require(nftContract.getApproved(tokenId) == address(this), "Token not approve for burn");
        nftContract.burn(tokenId);
        emit NFTBurned(collection, tokenId, msg.sender, block.timestamp, tokenURI);
    }

    receive() external payable {}
}
