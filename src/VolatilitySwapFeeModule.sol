// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/utils/math/Math.sol";
import {SwapFeeModuleData, ISwapFeeModule} from "@valantis-core/swap-fee-modules/interfaces/ISwapFeeModule.sol";
/**
 * @title Volatility Swap Fee Module.
 * @dev Volatility Swap Fee Module for Valantis Sovereign Pool.
 */
contract VolatilitySwapFeeModule is ISwapFeeModule {

uint256 public immutable FEE_MIN;
uint256 public immutable FEE_MAX;
uint256 public immutable ALPHA;
uint256 public immutable VOLATILITY_MULTIPLIER;

uint256 public volatilityAccumulator;
uint256 public lastPrice;

constructor(
    uint256 _feeMin,
    uint256 _feeMax,
    uint256 _alpha,
    uint256 _volatilityMultiplier
) {
    require(_feeMin < _feeMax, "Invalid fee range");
    require(_volatilityMultiplier > 0, "Invalid volatility multiplier");
    
    FEE_MIN = _feeMin;
    FEE_MAX = _feeMax;
    ALPHA = _alpha;
    VOLATILITY_MULTIPLIER = _volatilityMultiplier;
    
    // Initialize state variables
    volatilityAccumulator = 0;
    lastPrice = 1e18;  // Initialize with 1.0
}

function getVolatilityOracle() external view returns (uint256) {
    return volatilityAccumulator;
}

function getCurrentFee() external view returns (uint256) {
    uint256 feeInBips = FEE_MIN + volatilityAccumulator * VOLATILITY_MULTIPLIER;
    feeInBips = Math.min(feeInBips, FEE_MAX);
    return Math.max(feeInBips, FEE_MIN);
}

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
        swapFeeModuleData.internalContext = abi.encode(0);
        return swapFeeModuleData;
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
        SwapFeeModuleData memory
    ) external {
        // Update volatility accumulator using the final price, discluding the fee.
        uint256 priceWithoutFee = _amountOut * 1e18 / (_amountInUsed * (1e18 - _effectiveFee));
        uint256 priceRatio = Math.log2(priceWithoutFee / lastPrice);
        volatilityAccumulator = EMA(priceRatio, ALPHA, volatilityAccumulator);
        lastPrice = priceWithoutFee;
    }

    // @dev Exponential Moving Average (EMA) pure function.
    // @param _value The value to calculate the EMA for.
    // @param _alpha The alpha value for the EMA.
    // @param _accumulator The accumulator value for the EMA.
    // @return The EMA value.   
    function EMA(uint256 _value, uint256 _alpha, uint256 _accumulator) internal pure returns (uint256) {
        return _value * _alpha + (1 - _alpha) * _accumulator;
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