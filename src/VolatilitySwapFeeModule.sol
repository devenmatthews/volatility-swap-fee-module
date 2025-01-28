// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/utils/math/Math.sol";
import {SwapFeeModuleData, ISwapFeeModule} from "@valantis-core/swap-fee-modules/interfaces/ISwapFeeModule.sol";
/**
 * @title Volatility Swap Fee Module.
 * @dev Volatility Swap Fee Module for Valantis Sovereign Pool.
 */

contract VolatilitySwapFeeModule is ISwapFeeModule {
    /**
    *
    *  CUSTOM ERRORS
    *
    */
    error VolatilitySwapFeeModule__OnlyPool();
    error VolatilitySwapFeeModule__OnlyOwner();
    error VolatilitySwapFeeModule__ZeroAddress();
    error VolatilitySwapFeeModule__PoolAlreadySet();

    /**
     *
     *  CONSTANTS
     *
     */
    uint256 public immutable FEE_MIN;
    uint256 public immutable FEE_MAX;
    uint256 public immutable ALPHA;
    uint256 public immutable VOLATILITY_MULTIPLIER;
    uint256 public constant BIPS = 10_000;

    /**
     *
     *  STATE VARIABLES
     *
     */
    address public owner;
    address public pool;
    uint256 public volatilityAccumulator;
    uint256 public lastPrice;

    /**
     *
     *  CONSTRUCTOR
     *
     */
    constructor(
        uint256 _feeMin,
        uint256 _feeMax,
        uint256 _alpha,
        uint256 _volatilityMultiplier
    ) {
        require(_feeMin < _feeMax, "Invalid fee range");
        require(_volatilityMultiplier > 0, "Invalid volatility multiplier");
        require(_alpha > 0 && _alpha < 1e6, "Invalid alpha");
        
        FEE_MIN = _feeMin;
        FEE_MAX = _feeMax;
        ALPHA = _alpha;
        VOLATILITY_MULTIPLIER = _volatilityMultiplier;
        
        // Initialize state variables
        volatilityAccumulator = 0;
        lastPrice = 1e18;  // Initialize with 1.0
        owner = msg.sender;  // Set the owner to the deployer
    }

    /**
     *
     *  MODIFIERS
     *
     */
    // @dev Modifier to ensure the function is called by the pool
    modifier onlyPool() {
        if (msg.sender != pool) {
            revert VolatilitySwapFeeModule__OnlyPool();
        }
        _;
    }
    // @dev Modifier to ensure the function is called by the owner
    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert VolatilitySwapFeeModule__OnlyOwner();
        }
        _;
    }

    /**
     *
     *  VIEW FUNCTIONS
     *
     */

    // @dev Get the volatility accumulator
    function getVolatilityOracle() external view returns (uint256) {
        return volatilityAccumulator;
    }

    function getCurrentFee() external view returns (uint256) {
        uint256 feeInBips = FEE_MIN + volatilityAccumulator * VOLATILITY_MULTIPLIER;
        feeInBips = Math.min(feeInBips, FEE_MAX);
        return Math.max(feeInBips, FEE_MIN);
    }

    // @dev Get the swap fee in bips
    function getSwapFeeInBips(
            address,
            address,
            uint256,
            address,
            bytes memory
        ) external view returns (SwapFeeModuleData memory swapFeeModuleData) {
            // Calculate the fee in bips based on the volatility accumulator prior to the swap.
            uint256 feeInBips = FEE_MIN + volatilityAccumulator * VOLATILITY_MULTIPLIER;
            feeInBips = Math.min(feeInBips, FEE_MAX);
            feeInBips = Math.max(feeInBips, FEE_MIN);
            // Swap fee in `SovereignPool::swap` is applied as:
            // amountIn * BIPS / (BIPS + swapFeeModuleData.feeInBips),
            // but our parametrization assumes the form: amountIn * (BIPS - feeInBips) / BIPS
            // Hence we need to equate both and solve for `swapFeeModuleData.feeInBips`,
            // with the constraint that feeInBips <= 5_000
            swapFeeModuleData.feeInBips = (BIPS * BIPS) / (BIPS - feeInBips) - BIPS;
            //swapFeeModuleData.feeInBips = feeInBips;
            swapFeeModuleData.internalContext = abi.encode(0);

            return swapFeeModuleData;
        }

    /**
     *
     *  EXTERNAL FUNCTIONS
     *
     */
    function setPool(address _pool) external onlyOwner {
        if (_pool == address(0)) revert VolatilitySwapFeeModule__ZeroAddress();
        // Pool can only be set once
        if (pool != address(0)) revert VolatilitySwapFeeModule__PoolAlreadySet();
        pool = _pool;
    }

    // @dev Callback function called by the pool after the swap has finished. ( Sovereign Pools )
    // @param _effectiveFee The effective fee charged for the swap.
    // @param _amountInUsed The amount of tokenIn used for the swap.
    // @param _amountOut The amount of the tokenOut transferred to the user.
    // @param _swapFeeModuleData The context data returned by getSwapFeeInBips. 
    function callbackOnSwapEnd(
        uint256 _effectiveFee,
        uint256 _amountInUsed,
        uint256 _amountOut,
        SwapFeeModuleData memory _swapFeeModuleData
    ) external onlyPool {
        // Update volatility accumulator using the final price, discluding the fee.
        uint256 priceWithoutFee = _amountOut * 1e18 / (_amountInUsed * _swapFeeModuleData.feeInBips);
        uint256 priceRatio = Math.log2(priceWithoutFee / lastPrice);
        volatilityAccumulator = EMA(priceRatio, ALPHA, volatilityAccumulator);
        lastPrice = priceWithoutFee;
    }

    /**
        *
        *  INTERNAL FUNCTIONS
        *
        */

    // @dev Exponential Moving Average (EMA) pure function.
    // @param _value The value to calculate the EMA for.
    // @param _alpha The alpha value for the EMA.
    // @param _accumulator The accumulator value for the EMA.
    // @return The EMA value.   
    function EMA(uint256 _value, uint256 _alpha, uint256 _accumulator) internal pure returns (uint256) {
        return (_value * _alpha + (1e6 - _alpha) * _accumulator) / 1e6;
    }

    // IGNORE THIS FUNCTION
    // For compatibility with the Universal Pool Type (not implemented)
    function callbackOnSwapEnd(
        uint256,
        int24,
        uint256,
        uint256,
        SwapFeeModuleData memory
    ) external pure {
        // not implemented
        return;
    }
}