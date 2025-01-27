// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/utils/math/Math.sol";
import {SwapFeeModuleData, ISwapFeeModule} from "@valantis-core/swap-fee-modules/interfaces/ISwapFeeModule.sol";
/**
 * @title Volatility Swap Fee Module.
 * @dev Volatility Swap Fee Module for Valantis Sovereign Pool.
 */
abstract contract VolatilitySwapFeeModule is ISwapFeeModule {

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
    }

function getSwapFeeInBips(
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn,
        address _user,
        bytes memory _swapFeeModuleContext
    ) external returns (SwapFeeModuleData memory swapFeeModuleData) {
        // Calculate the fee in bips based on the volatility accumulator prior to the swap.
        uint256 feeInBips = FEE_MIN + volatilityAccumulator * VOLATILITY_MULTIPLIER;
        feeInBips = Math.min(feeInBips, FEE_MAX);
        feeInBips = Math.max(feeInBips, FEE_MIN);
        swapFeeModuleData.feeInBips = feeInBips;
        swapFeeModuleData.internalContext = abi.encode(0);
        return swapFeeModuleData;
    }

    function callbackOnSwapEnd(
        uint256 _effectiveFee,
        uint256 _amountInUsed,
        uint256 _amountOut,
        bytes memory _swapFeeModuleContext
    ) external {
        // Update volatility accumulator using the final price, discluding the fee.
        uint256 priceWithoutFee = _amountOut * 1e18 / (_amountInUsed * (1e18 - _effectiveFee));
        uint256 priceRatio = Math.log2(priceWithoutFee / lastPrice);
        volatilityAccumulator = EMA(priceRatio, ALPHA, volatilityAccumulator);
        lastPrice = priceWithoutFee;
    }

    function EMA(uint256 _value, uint256 _alpha, uint256 _accumulator) internal pure returns (uint256) {
        return _value * _alpha + (1 - _alpha) * _accumulator;
    }
}