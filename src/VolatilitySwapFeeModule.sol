// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/utils/math/Math.sol";
import {ISwapFeeModule} from "@valantis-core/src/swap-fee-modules/interfaces/ISwapFeeModule.sol";
import {ISovereignOracle} from "@valantis-core/src/oracles/interfaces/ISovereignOracle.sol";
/**
 * @title Volatility Swap Fee Module.
 * @dev Volatility Swap Fee Module for Valantis Sovereign Pool.
 */
contract VolatilitySwapFeeModule {

    struct SwapFeeModuleData {
    uint256 feeInBips;
    bytes internalContext;
}

// Fee tiers
uint256 public immutable FEE_MIN;
uint256 public immutable FEE_MAX;
// Volatility multiplier
uint256 public immutable VOLATILITY_MULTIPLIER;
// Volatility accumulator
uint256 public volatilityAccumulator;

constructor(
    uint256 _feeMin,
    uint256 _feeMax,
    uint256 _volatilityMultiplier
) {
    require(_feeMin < _feeMax, "Invalid fee range");
    require(_volatilityMultiplier > 0, "Invalid volatility multiplier");
    
    FEE_MIN = _feeMin;
    FEE_MAX = _feeMax;
    VOLATILITY_MULTIPLIER = _volatilityMultiplier;
}

function getSwapFeeInBips(
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn,
        address _user,
        bytes memory _swapFeeModuleContext
    ) external returns (SwapFeeModuleData memory swapFeeModuleData) {
        volatilityAccumulator = 0;

        swapFeeModuleData.feeInBips = FEE_MIN + volatilityAccumulator * VOLATILITY_MULTIPLIER;
        swapFeeModuleData.internalContext = abi.encode(0);
        return swapFeeModuleData;
    }
}