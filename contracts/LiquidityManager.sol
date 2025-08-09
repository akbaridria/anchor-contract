// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "./interfaces/ILiquidityManager.sol";
import "./PullBasedRewardDistribution.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract LiquidityManager is ILiquidityManager, ReentrancyGuard, Ownable {
    PullBasedRewardDistribution public immutable rewardDistributor;

    uint256 public totalLiquidity;
    uint256 public lockedLiquidity;

    constructor() Ownable(msg.sender) {
        rewardDistributor = new PullBasedRewardDistribution();
    }

    function addLiquidity(address provider, uint256 amount) external override onlyOwner {
        rewardDistributor.addStake(provider, amount);
        totalLiquidity += amount;
    }

    function removeLiquidity(address provider, uint256 amount) external override onlyOwner returns (uint256) {
        uint256 actualAmount = rewardDistributor.removeStake(provider, amount);
        totalLiquidity -= actualAmount;

        return actualAmount;
    }

    function lockLiquidity(uint256 amount) external override onlyOwner {
        require(lockedLiquidity + amount <= totalLiquidity, "Insufficient liquidity");
        lockedLiquidity += amount;
    }

    function unlockLiquidity(uint256 amount) external override onlyOwner {
        require(lockedLiquidity >= amount, "Invalid unlock amount");
        lockedLiquidity -= amount;
    }

    function distributePnL(int256 pnl) external override onlyOwner {
        rewardDistributor.distributePnL(pnl);
        uint256 pnlAbs = uint256(pnl > 0 ? pnl : -pnl);
        if (pnl > 0) {
            totalLiquidity += pnlAbs;
        } else {
            totalLiquidity -= pnlAbs;
        }
    }

    // View functions
    function getTotalLiquidity() external view override returns (uint256) {
        return totalLiquidity;
    }

    function getAvailableLiquidity() public view override returns (uint256) {
        return totalLiquidity - lockedLiquidity;
    }

    function getProviderBalance(address provider) external view override returns (uint256) {
        (,, uint256 effectiveBalance) = rewardDistributor.getProviderInfo(provider);
        return effectiveBalance;
    }
}
