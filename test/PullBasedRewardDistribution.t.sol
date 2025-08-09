// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import "../contracts/PullBasedRewardDistribution.sol";

contract PullBasedRewardDistributionTest is Test {
    PullBasedRewardDistribution public distributor;
    address public userA = address(0x1);
    address public userB = address(0x2);

    function setUp() public {
        distributor = new PullBasedRewardDistribution();
    }

    function testScenario() public {
        console.log("=== Initial State ===");
        (uint256 totalStaked, int256 accRewardPerShare, int256 totalPnL) = distributor.getPoolInfo();
        console.log("Total Staked:", totalStaked);
        console.log("Acc Reward Per Share:", accRewardPerShare);
        console.log("Total PnL:", totalPnL);

        console.log("\n=== User A adds 100 USDC ===");
        distributor.addStake(userA, 100e6);

        (uint256 stakeA, int256 pendingRewardsA, uint256 effectiveBalanceA) = distributor.getProviderInfo(userA);
        console.log("User A stake:", stakeA);
        console.log("User A pending rewards:", uint256(pendingRewardsA >= 0 ? pendingRewardsA : -pendingRewardsA));
        console.log("User A rewards sign:", pendingRewardsA >= 0 ? "positive" : "negative");
        console.log("User A effective balance:", effectiveBalanceA);

        (totalStaked, accRewardPerShare, totalPnL) = distributor.getPoolInfo();
        console.log("Total Staked:", totalStaked);
        console.log("Total PnL:", totalPnL);

        console.log("\n=== Distribute +10 USDC reward ===");
        distributor.distributePnL(int256(10e6));

        (stakeA, pendingRewardsA, effectiveBalanceA) = distributor.getProviderInfo(userA);
        console.log("User A stake:", stakeA);
        console.log("User A pending rewards:", pendingRewardsA);
        console.log("User A effective balance:", effectiveBalanceA);

        (totalStaked, accRewardPerShare, totalPnL) = distributor.getPoolInfo();
        console.log("Total Staked:", totalStaked);
        console.log("Acc Reward Per Share:", accRewardPerShare);
        console.log("Total PnL:", totalPnL);

        console.log("\n=== User B adds 60 USDC ===");
        distributor.addStake(userB, 60e6);

        (uint256 stakeB, int256 pendingRewardsB, uint256 effectiveBalanceB) = distributor.getProviderInfo(userB);
        console.log("User B stake:", stakeB);
        console.log("User B pending rewards:", uint256(pendingRewardsB >= 0 ? pendingRewardsB : -pendingRewardsB));
        console.log("User B rewards sign:", pendingRewardsB >= 0 ? "positive" : "negative");
        console.log("User B effective balance:", effectiveBalanceB);

        (stakeA, pendingRewardsA, effectiveBalanceA) = distributor.getProviderInfo(userA);
        console.log("User A stake:", stakeA);
        console.log("User A pending rewards:", pendingRewardsA);
        console.log("User A effective balance:", effectiveBalanceA);

        (totalStaked, accRewardPerShare, totalPnL) = distributor.getPoolInfo();
        console.log("Total Staked:", totalStaked);
        console.log("Total PnL:", totalPnL);

        console.log("\n=== Distribute -20 USDC loss ===");
        distributor.distributePnL(int256(-20e6));

        (stakeA, pendingRewardsA, effectiveBalanceA) = distributor.getProviderInfo(userA);
        console.log("User A stake:", stakeA);
        console.log("User A pending rewards:", pendingRewardsA);
        console.log("User A effective balance:", effectiveBalanceA);

        (stakeB, pendingRewardsB, effectiveBalanceB) = distributor.getProviderInfo(userB);
        console.log("User B stake:", stakeB);
        console.log("User B pending rewards:", pendingRewardsB);
        console.log("User B effective balance:", effectiveBalanceB);

        (totalStaked, accRewardPerShare, totalPnL) = distributor.getPoolInfo();
        console.log("Total Staked:", totalStaked);
        console.log("Acc Reward Per Share:", accRewardPerShare);
        console.log("Total PnL:", totalPnL);

        console.log("\n=== Testing Withdrawal Amounts ===");
        uint256 userAWithdrawalAmount = distributor.removeStake(userA, 50e6);
        console.log("User A tries to withdraw 50 USDC, gets:", userAWithdrawalAmount);

        uint256 userBWithdrawalAmount = distributor.removeStake(userB, 30e6);
        console.log("User B tries to withdraw 30 USDC, gets:", userBWithdrawalAmount);

        console.log("\n=== Final State ===");
        (stakeA, pendingRewardsA, effectiveBalanceA) = distributor.getProviderInfo(userA);
        console.log("User A final stake:", stakeA);
        console.log("User A final effective balance:", effectiveBalanceA);

        (stakeB, pendingRewardsB, effectiveBalanceB) = distributor.getProviderInfo(userB);
        console.log("User B final stake:", stakeB);
        console.log("User B final effective balance:", effectiveBalanceB);

        (totalStaked, accRewardPerShare, totalPnL) = distributor.getPoolInfo();
        console.log("Final Total Staked:", totalStaked);
        console.log("Final Total PnL:", totalPnL);

        assertEq(totalPnL, -10e6, "Total PnL should be -10 USDC");

        uint256 totalEffectiveBalance = effectiveBalanceA + effectiveBalanceB;
        console.log("Total effective balance:", totalEffectiveBalance);
        console.log("Original stakes remaining:", stakeA + stakeB);
    }
}
