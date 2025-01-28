// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ValidlyFactory, Validly} from "@validly/ValidlyFactory.sol";
import {VolatilitySwapFeeModule} from "./VolatilitySwapFeeModule.sol";
import {SovereignPoolConstructorArgs} from "@valantis-core/pools/structs/SovereignPoolStructs.sol";
import {ISovereignPool} from "@valantis-core/pools/interfaces/ISovereignPool.sol";

contract ValidlyVolatileFactory is ValidlyFactory {
    constructor(
        address _protocolFactory
    ) ValidlyFactory(_protocolFactory, 1) {} // Pass 1 (0.01%) instead of 0

    function createPairWithVolatilityFee(
        address _token0, 
        address _token1, 
        uint256 _alpha,
        uint256 _volatilityMultiplier
    ) external returns (address) {
        (_token0, _token1) = _token0 < _token1 ? (_token0, _token1) : (_token1, _token0);

        bytes32 poolKey = keccak256(abi.encode(_token0, _token1, false));

        if (pools[poolKey] != address(0)) {
            revert ValidlyFactory__createPair_alreadyDeployed();
        }

        // Deploy a new VolatilitySwapFeeModule for this specific pool
        VolatilitySwapFeeModule volatilityFeeModule = new VolatilitySwapFeeModule(
            100, // feeMin    
            1500, // feeMax
            _alpha, // alpha
            _volatilityMultiplier // volatilityMultiplier
        );

        SovereignPoolConstructorArgs memory args = SovereignPoolConstructorArgs(
            _token0,
            _token1,
            address(protocolFactory),
            address(this), // poolManager
            address(0), // sovereignVault
            address(0), // verifierModule
            false,
            false,
            0,
            0,
            0  // Base fee is handled by VolatilitySwapFeeModule
        );

        address pool = protocolFactory.deploySovereignPool(args);

        Validly validly = new Validly{salt: poolKey}(pool, false);

        ISovereignPool(pool).setALM(address(validly));
        ISovereignPool(pool).setSwapFeeModule(address(volatilityFeeModule));
        VolatilitySwapFeeModule(address(volatilityFeeModule)).setPool(pool);

        // Add check to ensure setSwapFeeModule succeeded
        if (ISovereignPool(pool).swapFeeModule() != address(volatilityFeeModule)) {
            revert("Failed to set swap fee module");
        }

        pools[poolKey] = pool;

        emit PoolCreated(pool, _token0, _token1, false);

        return address(validly);
    }
} 