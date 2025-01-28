// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ProtocolFactory} from "@valantis-core/protocol-factory/ProtocolFactory.sol";
import {ISovereignPool} from "@valantis-core/pools/interfaces/ISovereignPool.sol";
import {SovereignPoolSwapParams, SovereignPoolSwapContextData} from "@valantis-core/pools/structs/SovereignPoolStructs.sol";
import {SovereignPoolFactory} from "@valantis-core/pools/factories/SovereignPoolFactory.sol";
import {ValidlyVolatileFactory} from "../src/ValidlyVolatileFactory.sol";
import {VolatilitySwapFeeModule} from "../src/VolatilitySwapFeeModule.sol";
import {Validly} from "@validly/Validly.sol";

contract VolatilitySwapFeeTest is Test {
    ValidlyVolatileFactory public factory;
    VolatilitySwapFeeModule public feeModule;
    ERC20Mock public token0;
    ERC20Mock public token1;
    ISovereignPool public volatilePool;
    Validly public volatilePair;
    uint256 public MIN_FEE = 100;
    
    function setUp() public {
        // Create dummy tokens
        token0 = new ERC20Mock();
        token1 = new ERC20Mock();

        // Setup Protocol Factory
        ProtocolFactory protocolFactory = new ProtocolFactory(address(this));
        SovereignPoolFactory poolFactory = new SovereignPoolFactory();
        protocolFactory.setSovereignPoolFactory(address(poolFactory));

        // Create ValidlyVolatileFactory
        factory = new ValidlyVolatileFactory(address(protocolFactory));

        // Create volatile pair with custom volatility parameters
        volatilePair = Validly(factory.createPairWithVolatilityFee(
            address(token0),
            address(token1),
            9, // alpha (99%)
            100   // volatilityMultiplier
        ));

        volatilePool = volatilePair.pool();
        feeModule = VolatilitySwapFeeModule(address(volatilePool.swapFeeModule()));
    }

    function test_increasingVolatility() public {
        // Mint and approve tokens
        token0.mint(address(this), 1000 ether);
        token1.mint(address(this), 1000 ether);
        
        // Approve both tokens for the Validly contract
        token0.approve(address(volatilePair), 1000 ether);
        token1.approve(address(volatilePair), 1000 ether);

        // Approve both tokens for sovereign pool
        token0.approve(address(volatilePool), 1000 ether);
        token1.approve(address(volatilePool), 1000 ether);

        // Add initial liquidity
        volatilePair.deposit(
            10 ether,  // amount0Desired
            10 ether,  // amount1Desired
            0,         // minShares
            block.timestamp + 1,  // deadline
            address(this),        // recipient
            ""                    // data
        );

        // First swap - should have base fee
        SovereignPoolSwapParams memory params = SovereignPoolSwapParams({
            isSwapCallback: false,
            isZeroToOne: true,
            amountIn: 1 ether,
            amountOutMin: 0,
            deadline: block.timestamp + 1,
            recipient: address(this),
            swapTokenOut: address(token0),
            swapContext: SovereignPoolSwapContextData({
                externalContext: "",
                verifierContext: "",
                swapCallbackContext: "",
                swapFeeModuleContext: ""
            })
        });

        volatilePool.swap(params);
        uint256 initialFee = feeModule.getCurrentFee();
        assertEq(MIN_FEE, initialFee, "Initial fee should be minimum fee");

        // Do multiple swaps back and forth to increase volatility
        // for(uint i = 0; i < 5; i++) {
        //     params.isZeroToOne = !params.isZeroToOne;
        //     params.swapTokenOut = params.isZeroToOne ? address(token1) : address(token0);
        //     volatilePool.swap(params);
        // }
        volatilePool.swap(params);

        // // // Check if fee increased
        uint256 finalFee = feeModule.getCurrentFee();
        assertGt(finalFee, initialFee, "Fee should increase with volatility");
    }
}