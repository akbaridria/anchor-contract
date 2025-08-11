// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract MockUSDC is ERC20, Ownable, ERC20Permit {
    uint8 public immutable DECIMALS = 6;

    constructor() ERC20("USD Coin", "USDC") Ownable(msg.sender) ERC20Permit("USD Coin") {
        _mint(msg.sender, 10_000_000_000 * 10 ** DECIMALS);
    }

    // for testing only we public the mint function since we are using mock usdc
    // in real implementation, we will use real usdc so do not need this anymore.
    function mint(uint256 amount) public {
        _mint(msg.sender, amount);
    }

    function mint() public {
        uint256 amount = 100 * 10 ** DECIMALS;
        _mint(msg.sender, amount);
    }

    function decimals() public pure override returns (uint8) {
        return DECIMALS;
    }
}
