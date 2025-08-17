// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import "../contracts/AnchorCore.sol";
import "../contracts/MockUSDC.sol";
import "../contracts/LiquidityManager.sol";
import "../contracts/Types.sol";

contract MockPyth {
    function getUpdateFee(bytes[] calldata) external pure returns (uint256) {
        return 0;
    }

    function updatePriceFeeds(bytes[] calldata) external payable {}

    function getPriceNoOlderThan(bytes32, uint256) external returns (PythStructs.Price memory) {
        return PythStructs.Price({price: int64(30000e8), conf: 0, expo: -8, publishTime: uint64(block.timestamp)});
    }
}

contract AnchorCoreTest is Test {
    AnchorCore anchorCore;
    MockUSDC usdc;
    MockPyth mockPyth;
    address gateway = address(0x123);
    address user = address(0x789);
    address resolver = address(0x111);

    function setUp() public {
        usdc = new MockUSDC();
        mockPyth = new MockPyth();
        anchorCore = new AnchorCore(payable(gateway), address(usdc), address(mockPyth));
        // Mint USDC to user for testing
        vm.prank(usdc.owner());
        usdc.mint(10000 * 10 ** usdc.decimals());
        vm.prank(usdc.owner());
        usdc.transfer(user, 1000 * 10 ** usdc.decimals());
        vm.startPrank(user);
        usdc.approve(address(anchorCore), 1000 * 10 ** usdc.decimals());
        vm.stopPrank();
        // Give liquidity to contract for tests using AnchorCore's addLiquidity
        vm.startPrank(user);
        anchorCore.addLiquidity(500_000 * 10 ** usdc.decimals());
        vm.stopPrank();
    }

    function testCreateOptions() public {
        vm.startPrank(user);
        bytes[] memory priceUpdateData = new bytes[](0); // mock
        uint256 size = 10 * 10 ** 3; // 3 decimals for size
        uint256 strikePrice = 35000e8;
        uint256 currentPrice = 30000e8; // Mocked by MockPyth
        uint256 premiumPerSize = 100_000_000; // from Types.sol
        uint256 premium = (size * premiumPerSize) / 1e3;
        uint256 expiry = block.timestamp + 1 days;
        uint256 maxPayout = (size * currentPrice) / 1e5;
        console.log("Calculated premium:", premium);
        console.log("Calculated maxPayout:", maxPayout);
        console.log("Size:", size);
        console.log("StrikePrice:", strikePrice);
        console.log("CurrentPrice:", currentPrice);
        console.log("Expiry:", expiry);
        anchorCore.createOptions(priceUpdateData, OptionType.CALL, expiry, premium, size, strikePrice);
        vm.stopPrank();
    }

    function testAddLiquidity() public {
        uint256 amount = 500 * 10 ** usdc.decimals();
        console.log("Liquidity to add:", amount);
        vm.prank(anchorCore.liquidityManager().owner());
        anchorCore.addLiquidity(amount);
        console.log("Total liquidity after add:", anchorCore.liquidityManager().getTotalLiquidity());
    }

    function testRemoveLiquidityRevertsIfInsufficient() public {
        uint256 amount = 1000 * 10 ** usdc.decimals();
        vm.startPrank(user);
        vm.expectRevert();
        anchorCore.removeLiquidity(amount);
        vm.stopPrank();
    }

    function testResolveOptionsRevertsIfNotExpired() public {
        vm.startPrank(user);
        bytes[] memory priceUpdateData = new bytes[](0);
        uint256 size = 10 * 10 ** 3;
        uint256 premium = (size * 100_000_000) / 1e3;
        console.log("Calculated premium:", premium);
        uint256 expiry = block.timestamp + 1 days;
        uint256 strikePrice = 30000e8;
        anchorCore.createOptions(priceUpdateData, OptionType.CALL, expiry, premium, size, strikePrice);
        vm.stopPrank();
        // Try to resolve before expiry
        vm.startPrank(resolver);
        vm.expectRevert();
        anchorCore.resolveOptions(0, priceUpdateData);
        vm.stopPrank();
    }

    function testClaimRewardRevertsIfNotOwner() public {
        vm.startPrank(user);
        bytes[] memory priceUpdateData = new bytes[](0);
        uint256 size = 10 * 10 ** 3;
        uint256 premium = (size * 100_000_000) / 1e3;
        console.log("Calculated premium:", premium);
        uint256 expiry = block.timestamp + 1 days;
        uint256 strikePrice = 30000e8;
        anchorCore.createOptions(priceUpdateData, OptionType.CALL, expiry, premium, size, strikePrice);
        vm.stopPrank();
        // Try to claim reward from non-owner
        vm.startPrank(resolver);
        vm.expectRevert();
        anchorCore.claimReward(0);
        vm.stopPrank();
    }
}
