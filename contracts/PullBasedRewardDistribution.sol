// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract PullBasedRewardDistribution {
    struct ProviderInfo {
        uint256 stake;
        int256 rewardDebt;
        uint256 lastUpdateTime;
    }

    struct PoolInfo {
        uint256 totalStaked;
        int256 accRewardPerShare;
        uint256 lastRewardTime;
        int256 totalPnL;
    }

    mapping(address => ProviderInfo) public providers;
    PoolInfo public pool;

    uint256 private constant PRECISION = 1e18;

    event LiquidityAdded(address indexed provider, uint256 amount, uint256 newStake);
    event LiquidityRemoved(address indexed provider, uint256 amount, uint256 remainingStake);
    event RewardsDistributed(int256 pnl, int256 accRewardPerShare);

    function addStake(address provider, uint256 amount) external {
        _updatePool();

        if (providers[provider].stake == 0) {
            providers[provider].rewardDebt = 0;
        }

        providers[provider].stake += amount;

        providers[provider].rewardDebt += (pool.accRewardPerShare * int256(amount)) / int256(PRECISION);
        providers[provider].lastUpdateTime = block.timestamp;

        pool.totalStaked += amount;

        emit LiquidityAdded(provider, amount, providers[provider].stake);
    }

    function removeStake(address provider, uint256 amount) external returns (uint256 actualAmount) {
        _updatePool();

        uint256 effectiveBalance = _getEffectiveBalance(provider);
        require(amount <= effectiveBalance, "Insufficient effective balance");

        int256 pendingRewards = _getPendingRewards(provider);

        uint256 stakeToRemove;

        if (pendingRewards >= 0) {
            uint256 positiveRewards = uint256(pendingRewards);

            if (amount <= positiveRewards) {
                stakeToRemove = 0;
            } else {
                stakeToRemove = amount - positiveRewards;
            }
        } else {
            stakeToRemove = amount;
        }

        if (stakeToRemove > 0) {
            require(providers[provider].stake >= stakeToRemove, "Insufficient stake");
            providers[provider].stake -= stakeToRemove;
            pool.totalStaked -= stakeToRemove;

            providers[provider].rewardDebt -= (pool.accRewardPerShare * int256(stakeToRemove)) / int256(PRECISION);
        }

        providers[provider].lastUpdateTime = block.timestamp;

        if (providers[provider].stake == 0) {
            delete providers[provider];
        }

        actualAmount = amount;

        emit LiquidityRemoved(provider, stakeToRemove, providers[provider].stake);
        return actualAmount;
    }

    function distributePnL(int256 pnl) external {
        if (pool.totalStaked == 0) return;

        _updatePool();

        pool.totalPnL += pnl;

        if (pnl != 0) {
            int256 rewardPerShare = (pnl * int256(PRECISION)) / int256(pool.totalStaked);
            pool.accRewardPerShare += rewardPerShare;
        }

        emit RewardsDistributed(pnl, pool.accRewardPerShare);
    }

    function _updatePool() internal {
        if (block.timestamp <= pool.lastRewardTime) return;
        pool.lastRewardTime = block.timestamp;
    }

    function _getPendingRewards(address provider) internal view returns (int256) {
        if (providers[provider].stake == 0) return 0;

        return (int256(providers[provider].stake) * pool.accRewardPerShare) / int256(PRECISION)
            - providers[provider].rewardDebt;
    }

    function _getEffectiveBalance(address provider) internal view returns (uint256) {
        if (providers[provider].stake == 0) return 0;

        int256 pendingRewards = _getPendingRewards(provider);
        int256 effectiveBalance = int256(providers[provider].stake) + pendingRewards;

        return effectiveBalance > 0 ? uint256(effectiveBalance) : 0;
    }

    function getProviderInfo(address provider)
        external
        view
        returns (uint256 stake, int256 pendingRewards, uint256 effectiveBalance)
    {
        if (providers[provider].stake == 0) return (0, 0, 0);

        stake = providers[provider].stake;
        pendingRewards = _getPendingRewards(provider);
        effectiveBalance = _getEffectiveBalance(provider);
    }

    function getPoolInfo() external view returns (uint256 totalStaked, int256 accRewardPerShare, int256 totalPnL) {
        return (pool.totalStaked, pool.accRewardPerShare, pool.totalPnL);
    }
}
