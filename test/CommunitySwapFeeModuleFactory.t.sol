// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {CommunitySwapFeeModuleFactory} from "../src/CommunitySwapFeeModuleFactory.sol";
import {CommunitySwapFeeModule} from "../src/CommunitySwapFeeModule.sol";
import {SovereignPool} from "@valantis-core/pools/SovereignPool.sol";
import {ISovereignPool} from "@valantis-core/pools/interfaces/ISovereignPool.sol";
import {Validly} from "@valantis/validly/Validly.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockERC721} from "./mocks/MockERC721.sol";

contract CommunitySwapFeeModuleFactoryTest is Test {
    CommunitySwapFeeModuleFactory public factory;
    SovereignPool public sovereignPool;
    MockERC20 public communityToken;
    MockERC721 public nft1;
    MockERC721 public nft2;
    address[] public eligibleNFTs;

    // Test constants
    uint256 constant TIER1_TOKEN_BALANCE = 1000e18;
    uint256 constant TIER2_TOKEN_BALANCE = 500e18;
    uint256 constant TIER1_NFT_BALANCE = 2;
    uint256 constant TIER2_NFT_BALANCE = 1;
    uint256 constant FEE_TIER_1 = 1000; // 10%
    uint256 constant FEE_TIER_2 = 3000; // 30%
    uint256 constant FEE_TIER_3 = 5000; // 50%

    function setUp() public {
        // Deploy tokens for the pool
        MockERC20 token0 = new MockERC20("Token0", "TK0");
        MockERC20 token1 = new MockERC20("Token1", "TK1");
        
        // Deploy Sovereign Pool
        sovereignPool = new SovereignPool(
            address(token0),
            address(token1),
            address(this) // admin
        );

        // Deploy community token and NFTs
        communityToken = new MockERC20("Community Token", "CTK");
        nft1 = new MockERC721("NFT1", "NFT1");
        nft2 = new MockERC721("NFT2", "NFT2");
        
        // Setup eligible NFTs array
        eligibleNFTs = new address[](2);
        eligibleNFTs[0] = address(nft1);
        eligibleNFTs[1] = address(nft2);

        // Deploy factory
        factory = new CommunitySwapFeeModuleFactory();
    }

    function testDeployModule() public {
        address moduleAddress = factory.deployModule(
            address(communityToken),
            TIER1_TOKEN_BALANCE,
            TIER2_TOKEN_BALANCE,
            eligibleNFTs,
            TIER1_NFT_BALANCE,
            TIER2_NFT_BALANCE,
            FEE_TIER_1,
            FEE_TIER_2,
            FEE_TIER_3,
            address(sovereignPool)
        );

        // Verify module is registered
        assertTrue(factory.isValidModule(moduleAddress));

        // Verify module parameters
        CommunitySwapFeeModule module = CommunitySwapFeeModule(moduleAddress);
        assertEq(address(module.communityToken()), address(communityToken));
        assertEq(module.tier1TokenBalance(), TIER1_TOKEN_BALANCE);
        assertEq(module.tier2TokenBalance(), TIER2_TOKEN_BALANCE);
        assertEq(module.tier1NFTBalance(), TIER1_NFT_BALANCE);
        assertEq(module.tier2NFTBalance(), TIER2_NFT_BALANCE);
        assertEq(module.FEE_TIER_1(), FEE_TIER_1);
        assertEq(module.FEE_TIER_2(), FEE_TIER_2);
        assertEq(module.FEE_TIER_3(), FEE_TIER_3);

        // Verify sovereign pool settings
        assertEq(address(sovereignPool.swapFeeModule()), moduleAddress);
        assertTrue(address(sovereignPool.liquidityModule()) != address(0));
    }

    function testFailDeployModuleWithZeroAddress() public {
        factory.deployModule(
            address(0), // Invalid community token address
            TIER1_TOKEN_BALANCE,
            TIER2_TOKEN_BALANCE,
            eligibleNFTs,
            TIER1_NFT_BALANCE,
            TIER2_NFT_BALANCE,
            FEE_TIER_1,
            FEE_TIER_2,
            FEE_TIER_3,
            address(sovereignPool)
        );
    }
} 