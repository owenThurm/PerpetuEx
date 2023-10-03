// SPDX-License Identifier: MIT

pragma solidity ^0.8.19;
// import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {Oracle} from "./Oracle.sol";

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

import {IPerpetuEx} from "./IPerpetuEx.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {console} from "forge-std/Console.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract PerpetuEx is ERC4626, IPerpetuEx, Ownable, ReentrancyGuard {
    struct Position {
        bool isLong;
        uint256 totalValue; // Accumulated USD value committed to the position
        uint256 size;
        uint256 collateral;
        address owner;
        uint256 openTimestamp;
    }

    using Oracle for uint256;
    using SafeERC20 for IERC20;
    using Math for uint256;
    using EnumerableSet for EnumerableSet.UintSet;

    AggregatorV3Interface public immutable i_priceFeed;

    IERC20 public immutable i_usdc;
    uint16 private constant DEAD_SHARES = 1000;

    // 20% of the liquidity reserved for safety reasons
    uint256 private constant MAX_UTILIZATION_PERCENTAGE_DECIMALS = 100;
    uint256 private constant SECONDS_PER_YEAR = 31536000; // 365 * 24 * 60 * 60
    uint256 private constant USDC_DECIMALS_ORACLE_MULTIPLIER = 1e18;
    uint256 private constant DECIMALS_DELTA = 1e12; // btc decimals - usdc decimals
    uint256 private constant DECIMALS_PRECISION = 1e3; // to avoid truncation precision loss (leverage calculation)

    uint8 private liquidationDenominator = 10; // 10% of the collateral
    uint256 private maxLeverage = 2 * 1e4; // 200000
    uint256 private borrowingRate = 10; //10% per year
    uint256 private maxUtilizationPercentage = 80; //80%

    uint256 private s_nonce;

    uint256 public s_totalLiquidityDeposited;
    int256 public s_totalPnl;
    uint256 public s_shortOpenInterest;
    uint256 public s_longOpenInterestInTokens;

    constructor(address priceFeed, IERC20 _usdc) ERC4626(_usdc) ERC20("PerpetuEx", "PXT") Ownable(msg.sender) {
        i_priceFeed = AggregatorV3Interface(priceFeed);
        i_usdc = IERC20(_usdc);

        //Avoiding the inflation attack by sending shares to the contract
        _mint(address(this), DEAD_SHARES);
    }

    mapping(address => uint256) public collateral; //User to collateral mapping
    mapping(uint256 => Position) public positions; // positionId => position
    mapping(address => EnumerableSet.UintSet) internal userToPositionIds; // user => positionIds
    mapping(address => int256) public userShortPnl; // user => short pnl
    mapping(address => int256) public userLongPnl; // user => long pnl

    //  ====================================
    //  ==== External/Public Functions =====
    //  ====================================

    function depositCollateral(uint256 _amount) external nonReentrant {
        if (_amount < 0) revert PerpetuEx__InvalidAmount();
        collateral[msg.sender] += _amount;
        i_usdc.safeTransferFrom(msg.sender, address(this), _amount);
    }

    function withdrawCollateral() external {
        if (collateral[msg.sender] == 0) {
            revert PerpetuEx__InsufficientCollateral();
        }
        if (userToPositionIds[msg.sender].length() > 0) {
            revert PerpetuEx__OpenPositionExists();
        }
        uint256 withdrawalAmount = collateral[msg.sender];
        collateral[msg.sender] = 0;
        i_usdc.safeTransfer(msg.sender, withdrawalAmount);
    }

    function deposit(uint256 assets, address receiver) public override nonReentrant returns (uint256 shares) {
        uint256 newTotalLiquidity = s_totalLiquidityDeposited + assets;
        shares = super.deposit(assets, receiver);
        s_totalLiquidityDeposited = newTotalLiquidity;
    }

    function withdraw(uint256 assets, address receiver, address owner)
        public
        override
        nonReentrant
        returns (uint256 shares)
    {
        uint256 newTotalLiquidity = s_totalLiquidityDeposited - assets;
        _maxLiquidityUtilization(assets);
        shares = super.withdraw(assets, receiver, owner);
        s_totalLiquidityDeposited = newTotalLiquidity;
    }

    function mint(uint256 shares, address receiver) public override nonReentrant returns (uint256 assets) {
        assets = super.mint(shares, receiver);
        s_totalLiquidityDeposited += assets;
    }

    function redeem(uint256 shares, address receiver, address owner)
        public
        override
        nonReentrant
        returns (uint256 assets)
    {
        assets = super.redeem(shares, receiver, owner);
        s_totalLiquidityDeposited -= assets;
    }

    function createPosition(uint256 _size, bool _isLong) external nonReentrant {
        if (_size == 0 || _calculateUserLeverage(_size, msg.sender) > maxLeverage) {
            revert PerpetuEx__InvalidSize();
        }
        //TODO: Add support for more orders from the same user. For now we block it.
        if (userToPositionIds[msg.sender].length() > 0) {
            revert PerpetuEx__OpenPositionExists();
        }
        ++s_nonce;
        uint256 currentPrice = getPriceFeed();
        Position memory newPosition = Position({
            size: _size,
            collateral: collateral[msg.sender],
            totalValue: _size * currentPrice,
            owner: msg.sender,
            isLong: _isLong,
            openTimestamp: block.timestamp
        });
        _maxLiquidityUtilization(0);
        _updateOpenInterests(_isLong, _size, currentPrice, PositionAction.Open);
        positions[s_nonce] = newPosition;
        userToPositionIds[msg.sender].add(s_nonce);
    }

    function closePosition(uint256 _positionId) public {
        Position storage position = positions[_positionId];
        if (_positionId == 0) revert PerpetuEx__InvalidPositionId();
        if (position.owner != msg.sender) revert PerpetuEx__NotOwner();
        uint256 borrowingFees = _borrowingFees(_positionId);
        int256 pnl = _calculateUserPnl(_positionId, position.isLong) - int256(borrowingFees);
        uint256 collateralAmount = position.collateral;
        if (pnl > 0) {
            uint256 profits = uint256(pnl);
            _updateOpenInterests(position.isLong, position.size, getAverageOpenPrice(_positionId), PositionAction.Close);
            s_totalPnl -= int256(profits);
            userToPositionIds[msg.sender].remove(_positionId);
            delete positions[_positionId];
            uint256 profitRealized = profits + collateralAmount;
            i_usdc.safeTransfer(msg.sender, profitRealized);
        }
        if (pnl <= 0) {
            uint256 unsignedPnl = SignedMath.abs(pnl);
            _updateOpenInterests(position.isLong, position.size, getAverageOpenPrice(_positionId), PositionAction.Close);
            s_totalPnl += int256(unsignedPnl);
            userToPositionIds[msg.sender].remove(_positionId);
            delete positions[_positionId];
            uint256 lossRealized = collateralAmount - unsignedPnl;
            i_usdc.safeTransfer(msg.sender, lossRealized);
        }
    }

    function increaseSize(uint256 _positionId, uint256 _size) external nonReentrant {
        Position storage position = positions[_positionId];
        if (position.owner != msg.sender) revert PerpetuEx__NotOwner();
        uint256 currentPrice = getPriceFeed();
        uint256 borrowingFees = _borrowingFees(_positionId);
        s_totalPnl -= int256(borrowingFees);
        positions[_positionId] = _updateCollateral(position, borrowingFees);
        if (_size == 0 || _calculateUserLeverage(_size, msg.sender) > maxLeverage) {
            revert PerpetuEx__InvalidSize();
        }
        _maxLiquidityUtilization(0);
        uint256 addedValue = _size * currentPrice;
        position = positions[_positionId];
        _updateOpenInterests(position.isLong, _size, currentPrice, PositionAction.IncreaseSize);
        position.totalValue += addedValue;
        position.size += _size;
        position.openTimestamp = block.timestamp;
        positions[_positionId] = position;
    }

    function decreaseSize(uint256 _positionId, uint256 _size) external nonReentrant {
        Position memory position = positions[_positionId];
        if (position.owner != msg.sender) revert PerpetuEx__NotOwner();
        if (_size == 0) {
            revert PerpetuEx__InvalidSize();
        }
        uint256 currentPrice = getPriceFeed();
        uint256 updatedSize = position.size - _size;
        if (updatedSize == 0) {
            closePosition(_positionId);
            return;
        }
        _updateOpenInterests(position.isLong, _size, currentPrice, PositionAction.DecreaseSize);
        int256 realizedPnl;
        uint256 averagePrice = getAverageOpenPrice(_positionId);
        uint256 borrowingFees = _borrowingFees(_positionId);
        int256 pnl = _calculateUserPnl(_positionId, position.isLong);
        position = _updateCollateral(position, borrowingFees);
        realizedPnl = (pnl * int256(_size)) / int256(position.size);
        s_totalPnl += realizedPnl;
        uint256 collateralAmount = (position.collateral * _size) / position.size;
        position.size -= _size;
        position.totalValue -= _size * averagePrice;
        position.openTimestamp = block.timestamp;
        if (realizedPnl > 0) {
            uint256 profits = uint256(realizedPnl);
            uint256 profitRealized = profits + collateralAmount;
            positions[_positionId] = _updateCollateral(position, profitRealized);
            i_usdc.safeTransfer(msg.sender, profitRealized);
        } else if (pnl <= 0) {
            uint256 unsignedPnl = SignedMath.abs(realizedPnl);
            uint256 lossRealized = collateralAmount - unsignedPnl;
            positions[_positionId] = _updateCollateral(position, lossRealized);
            i_usdc.safeTransfer(msg.sender, lossRealized);
        }
    }

    function increaseCollateral(uint256 _positionId, uint256 _collateral) external nonReentrant {
        Position storage position = positions[_positionId];
        if (_collateral == 0) revert PerpetuEx__InvalidCollateral();
        if (position.owner != msg.sender) revert PerpetuEx__NotOwner();
        position.collateral += _collateral;
        i_usdc.safeTransferFrom(msg.sender, address(this), _collateral);
    }

    function decreaseCollateral(uint256 _amount) external {
        if (collateral[msg.sender] < _amount) {
            revert PerpetuEx__InsufficientCollateral();
        }
        if (_amount == 0) revert PerpetuEx__InvalidAmount();

        uint256 userCollateral = collateral[msg.sender];
        collateral[msg.sender] = userCollateral - _amount;
        Position memory position = positions[userToPositionIds[msg.sender].at(0)];
        uint256 size = position.size;
        uint256 updatedLeverage = _calculateUserLeverage(size, msg.sender);
        if (updatedLeverage > maxLeverage) {
            revert PerpetuEx__InvalidAmount();
        }
        i_usdc.safeTransfer(msg.sender, _amount);
    }

    function liquidate(address _user) external nonReentrant {
        uint256 positionId = userToPositionIds[_user].at(0);
        Position memory position = positions[positionId];
        uint256 size = position.size;
        bool isLong = position.isLong;
        uint256 userLeverage = _calculateUserLeverage(size, _user);
        uint256 borrowingFees = _borrowingFees(positionId);
        uint256 price = getPriceFeed();

        if (userLeverage <= maxLeverage) revert PerpetuEx__NoLiquidationNeeded();

        uint256 newCollateral = collateral[_user] - borrowingFees;
        uint256 liquidatorFee = newCollateral / liquidationDenominator;
        uint256 backToProtocol = newCollateral - liquidatorFee + borrowingFees;
        s_totalLiquidityDeposited += backToProtocol;
        _updateCollateral(position, collateral[_user]);
        _updateOpenInterests(isLong, size, price, PositionAction.Close);
        delete positions[positionId];
        //TODO: Add support for more orders from the same user. For now we block it.
        userToPositionIds[_user].remove(positionId);

        IERC20(i_usdc).safeTransfer(msg.sender, liquidatorFee);
    }

    /// ====================================
    /// ======= Internal Functions =========
    /// ====================================
    function _borrowingFees(uint256 _positionId) internal view returns (uint256) {
        Position storage position = positions[_positionId];
        uint256 sizeInUsdc = position.totalValue;
        uint256 secondsPositionHasExisted = block.timestamp - position.openTimestamp;
        uint256 borrowingPerSizePerSecond = USDC_DECIMALS_ORACLE_MULTIPLIER / (borrowingRate * SECONDS_PER_YEAR);
        uint256 numerator = sizeInUsdc * secondsPositionHasExisted * borrowingPerSizePerSecond;
        uint256 borrowingFees = numerator / USDC_DECIMALS_ORACLE_MULTIPLIER;
        return borrowingFees;
    }

    /**
     * @dev Compute the liquidity reserve restriction and substract the total pnl of traders from it
     */
    function _updatedLiquidity() internal view returns (uint256 updatedLiquidity) {
        uint256 liquidityReserveRestriction =
            totalAssets().mulDiv(maxUtilizationPercentage, MAX_UTILIZATION_PERCENTAGE_DECIMALS);
        uint256 totalPnl = SignedMath.abs(s_totalPnl);
        if (s_totalPnl >= 0) {
            updatedLiquidity = liquidityReserveRestriction - totalPnl;
            return updatedLiquidity;
        }
        if (s_totalPnl < 0) {
            updatedLiquidity = liquidityReserveRestriction + totalPnl;
            return updatedLiquidity;
        }
    }

    function _totalOpenInterest(bool _isLong, uint256 _size, uint256 _currentPrice)
        internal
        view
        returns (uint256 totalOpenInterestValue)
    {
        // Calculate new open interests
        uint256 newLongOpenInterestInTokens = _isLong ? s_longOpenInterestInTokens + _size : s_longOpenInterestInTokens;

        uint256 newShortOpenInterest = !_isLong ? s_shortOpenInterest + (_size * _currentPrice) : s_shortOpenInterest;

        // Calculate the total open interest value
        totalOpenInterestValue = (newLongOpenInterestInTokens * _currentPrice) + newShortOpenInterest;
    }

    function _updateOpenInterests(bool _isLong, uint256 _size, uint256 _price, PositionAction positionAction)
        internal
    {
        if (_isLong) {
            if (positionAction == PositionAction.Open || positionAction == PositionAction.IncreaseSize) {
                s_longOpenInterestInTokens += _size;
            } else if (positionAction == PositionAction.Close || positionAction == PositionAction.DecreaseSize) {
                s_longOpenInterestInTokens -= _size;
            }
        } else if (!_isLong) {
            uint256 valueChange = _size * _price;
            if (positionAction == PositionAction.Open || positionAction == PositionAction.IncreaseSize) {
                s_shortOpenInterest += valueChange;
            } else if (positionAction == PositionAction.Close || positionAction == PositionAction.DecreaseSize) {
                s_shortOpenInterest -= valueChange;
            }
        } else {
            revert PerpetuEx__NoPositionChosen();
        }
    }

    function _updateCollateral(Position memory position, uint256 _amount)
        internal
        returns (Position memory updatedPosition)
    {
        position.collateral -= _amount;
        collateral[position.owner] -= _amount;
        updatedPosition = position;
    }

    function _convertToShares(uint256 assets, Math.Rounding rounding) internal view override returns (uint256) {
        if (totalSupply() == 0) return assets;
        return assets.mulDiv(totalSupply() + 10 ** _decimalsOffset(), totalAssets() + 1, rounding);
    }

    function _maxLiquidityUtilization(uint256 assets) internal view {
        uint256 currentPrice = getPriceFeed();
        uint256 updatedLiquidity = _updatedLiquidity() - assets;
        if (s_shortOpenInterest + (s_longOpenInterestInTokens * currentPrice) > updatedLiquidity * DECIMALS_DELTA) {
            revert PerpetuEx__InsufficientLiquidity();
        }
    }

    // =========================
    // ==== View/Pure Functions =====
    // =========================

    function userPositionIdByIndex(address user, uint256 index) public view returns (uint256) {
        return userToPositionIds[user].at(index);
    }

    function getPriceFeed() public view returns (uint256) {
        return Oracle.getBtcInUsdPrice(i_priceFeed);
    }

    function _getConversionRate(uint256 _amount) internal view returns (uint256) {
        return Oracle.convertPriceFromUsdToBtc(_amount, i_priceFeed);
    }

    function getAverageOpenPrice(uint256 _positionId) public view returns (uint256) {
        Position memory position = positions[_positionId];
        if (_positionId == 0 || position.totalValue == 0 || position.size == 0) {
            revert PerpetuEx__InvalidPositionId();
        }
        return position.totalValue / position.size;
    }

    function getTotalPnl() public view returns (int256) {
        return s_totalPnl;
    }

    function getTotalLiquidityDeposited() public view returns (uint256) {
        return s_totalLiquidityDeposited;
    }

    function getMaxUtilizationPercentage() public view returns (uint256) {
        return maxUtilizationPercentage;
    }

    function getMaxUtilizationPercentageDecimals() public pure returns (uint256) {
        return MAX_UTILIZATION_PERCENTAGE_DECIMALS;
    }

    function _calculateUserLeverage(uint256 _size, address _user) internal view returns (uint256 userLeverage) {
        uint256 priceFeed = getPriceFeed();
        uint256 priceFeedPrecisionAdjusted = priceFeed * DECIMALS_PRECISION; //1e18 * 1e4 = 1e22

        uint256 userCollateral = collateral[_user] * DECIMALS_DELTA; //1e6 * 1e12 = 1e18
        // 20 * 10 **4 = 200000
        if (userToPositionIds[_user].length() == 0) {
            userLeverage = _size.mulDiv(priceFeedPrecisionAdjusted, userCollateral);
            return userLeverage;
        }
        //TODO: Add support for more orders from the same user. For now we block it.
        uint256 positionId = userToPositionIds[_user].at(0);
        Position memory position = positions[positionId];
        int256 userPnl = _calculateUserPnl(positionId, position.isLong);

        if (userPnl == 0) {
            userLeverage = _size.mulDiv(priceFeedPrecisionAdjusted, userCollateral);
            return userLeverage;
        }
        if (userPnl > 0) {
            userLeverage = (_size.mulDiv(priceFeedPrecisionAdjusted, userCollateral + uint256(userPnl)));
            return userLeverage;
        }
        if (userPnl < 0) {
            uint256 unsignedPnl = SignedMath.abs(userPnl);
            userLeverage = (_size.mulDiv(priceFeedPrecisionAdjusted, userCollateral - unsignedPnl));
            return userLeverage;
        }
    }

    function _calculateUserPnl(uint256 _positionId, bool _isLong) internal view returns (int256 pnl) {
        uint256 currentPrice = getPriceFeed();
        uint256 averagePrice = getAverageOpenPrice(_positionId);
        Position storage position = positions[_positionId];

        if (_isLong) {
            pnl = (int256(currentPrice - averagePrice) * int256(position.size));
        } else if (!_isLong) {
            pnl = (int256(averagePrice - currentPrice) * int256(position.size));
        } else {
            revert PerpetuEx__NoPositionChosen();
        }
    }

    function maxWithdraw(address owner) public view override returns (uint256 maxWithdrawAllowed) {
        uint256 ownerAssets = super._convertToAssets(balanceOf(owner), Math.Rounding.Floor);
        uint256 updatedLiquidity = _updatedLiquidity();
        if (ownerAssets >= updatedLiquidity) {
            return maxWithdrawAllowed = updatedLiquidity;
        }

        if (ownerAssets < updatedLiquidity) {
            return maxWithdrawAllowed = ownerAssets;
        }
    }

    function maxRedeem(address owner) public view override returns (uint256 maxRedeemAllowed) {
        uint256 ownerAssets = super._convertToAssets(balanceOf(owner), Math.Rounding.Floor);

        uint256 updatedLiquidity = _updatedLiquidity();

        if (ownerAssets >= updatedLiquidity) {
            uint256 maxAssetsAllowed = updatedLiquidity;
            return maxRedeemAllowed = super._convertToShares(maxAssetsAllowed, Math.Rounding.Floor);
        }

        if (ownerAssets < updatedLiquidity) {
            return maxRedeemAllowed = super._convertToShares(ownerAssets, Math.Rounding.Floor);
        }
    }

    function totalAssets() public view override returns (uint256 assets) {
        if (s_totalPnl >= 0) {
            uint256 totalPnl = uint256(s_totalPnl);
            assets = s_totalLiquidityDeposited - totalPnl;
        }
        if (s_totalPnl < 0) {
            uint256 totalPnl = SignedMath.abs(s_totalPnl);
            assets = s_totalLiquidityDeposited + totalPnl;
        }
    }

    function getLeverage(address _user) public view returns (uint256 leverage) {
        Position memory position = positions[userToPositionIds[_user].at(0)];
        uint256 size = position.size;
        leverage = _calculateUserLeverage(size, _user);
    }

    function getBorrowingRate() public view returns (uint256) {
        return borrowingRate;
    }

    function getBorrowingFees(address _user) public view returns (uint256 borrowingFees) {
        borrowingFees = _borrowingFees(userToPositionIds[_user].at(0));
    }

    function getUserPnl(address _user) public view returns (int256) {
        Position memory position = positions[userToPositionIds[_user].at(0)];
        uint256 positionId = userToPositionIds[_user].at(0);
        int256 pnl = _calculateUserPnl(positionId, position.isLong);
        return pnl;
    }

    /// ====================================
    /// ======= Owner Functions =========
    /// ====================================

    function setMaxLeverage(uint256 _maxLeverage) external onlyOwner {
        maxLeverage = _maxLeverage;
    }

    function setBorrowingRate(uint256 _borrowingRate) external onlyOwner {
        borrowingRate = _borrowingRate;
    }

    function setMaxUtilizationPercentage(uint256 _maxUtilizationPercentage) external onlyOwner {
        maxUtilizationPercentage = _maxUtilizationPercentage;
    }

    function setLiquidationDenominator(uint8 _liquidationDenominator) external onlyOwner {
        liquidationDenominator = _liquidationDenominator;
    }
}
