// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "./MockUSDC.sol";

contract AnchorClient {
    MockUSDC public usdc;

    constructor(address _usdc) {
        usdc = MockUSDC(_usdc);
    }

    function addLiquidity() external {}
    function removeLiquidity() external {}
    function claimReward() external {}
}
