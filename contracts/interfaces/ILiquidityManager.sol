// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface ILiquidityManager {
    function addLiquidity(address provider, uint256 amount) external;
    function removeLiquidity(address provider, uint256 amount) external returns (uint256);
    function lockLiquidity(uint256 amount) external;
    function unlockLiquidity(uint256 amount) external;
    function distributePnL(int256 pnl) external;
    function getTotalLiquidity() external view returns (uint256);
    function getAvailableLiquidity() external view returns (uint256);
    function getProviderBalance(address provider) external view returns (uint256);
}
