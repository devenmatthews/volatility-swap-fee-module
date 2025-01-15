// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @title Community Discount Swap Fee Module.
 * @dev Community Discount Swap Fee Module for Valantis Sovereign Pool.
 */
contract CommunitySwapFeeModule {

    struct SwapFeeModuleData {
    uint256 feeInBips;
    bytes internalContext;
}

// Fee tiers
uint256 public immutable FEE_TIER_1;
uint256 public immutable FEE_TIER_2;
uint256 public immutable FEE_TIER_3; 

// New state variables
IERC20Metadata public immutable communityToken;
uint256 public immutable tier1TokenBalance;
uint256 public immutable tier2TokenBalance;
address[] public eligibleNFTs;
uint256 public immutable tier1NFTBalance;
uint256 public immutable tier2NFTBalance;

constructor(
    address _communityToken,
    uint256 _tier1TokenBalance,
    uint256 _tier2TokenBalance,
    address[] memory _eligibleNFTs,
    uint256 _tier1NFTBalance,
    uint256 _tier2NFTBalance,
    uint256 _feeTier1,
    uint256 _feeTier2,
    uint256 _feeTier3
) {
    communityToken = IERC20Metadata(_communityToken);
    tier1TokenBalance = _tier1TokenBalance;
    tier2TokenBalance = _tier2TokenBalance;
    eligibleNFTs = _eligibleNFTs;
    tier1NFTBalance = _tier1NFTBalance;
    tier2NFTBalance = _tier2NFTBalance;
    FEE_TIER_1 = _feeTier1;
    FEE_TIER_2 = _feeTier2;
    FEE_TIER_3 = _feeTier3;
}

function getSwapFeeInBips(
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn,
        address _user,
        bytes memory _swapFeeModuleContext
    ) external returns (SwapFeeModuleData memory swapFeeModuleData) {
        // Check NFT holdings
        uint256 nftCount = 0;
        for (uint256 i = 0; i < eligibleNFTs.length; i++) {
            if (IERC721(eligibleNFTs[i]).balanceOf(_user) > 0) {
                nftCount++;
            }
        }

        // Check token balance
        uint256 tokenBalance = communityToken.balanceOf(_user);

        // Determine fee tier based on criteria
        uint256 feeInBips;
        if (nftCount >= tier1NFTBalance && tokenBalance >= tier1TokenBalance) {
            feeInBips = FEE_TIER_1; // Lowest fee for users with Tier1 NFTs and Tier1 token balance
        } else if (nftCount >= tier2NFTBalance || tokenBalance >= tier2TokenBalance) {
            feeInBips = FEE_TIER_2; // Middle fee for users with Tier2 NFTs or Tier2 token balance
        } else {
            feeInBips = FEE_TIER_3; // Highest fee for users with insufficient NFTs and token balance
        }

        swapFeeModuleData.feeInBips = feeInBips;
        swapFeeModuleData.internalContext = abi.encode(0);
        return swapFeeModuleData;
    }
}