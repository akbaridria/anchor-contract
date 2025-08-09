// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@zetachain/protocol-contracts/contracts/zevm/GatewayZEVM.sol";
import "./LiquidityManager.sol";

contract AnchorCore is UniversalContract {
    GatewayZEVM public immutable gateway;
    LiquidityManager public immutable liquidityManager;

    enum OptionType {
        CALL,
        PUT
    }

    enum FunctionOptions {
        CREATE_OPTIONS,
        ADD_LIQUIDITY,
        REMOVE_LIQUIDITY
    }

    struct Options {
        OptionType optionType;
        uint256 maxPayout;
        uint256 strikePrice;
        uint256 currentPrice;
        uint256 size;
        address buyer;
        uint256 createdAt;
        uint256 expiry;
        bool isResolved;
    }

    uint256 constant MIN_OPTIONS_SIZE = 1_000;
    uint256 constant PREMIUM_PER_SIZE = 100_000_000;
    address public acceptedUSDC;

    uint256 optionId;

    mapping(uint256 => Options) public userOptions;

    error Unauthorized();

    modifier onlyGateway() {
        if (msg.sender != address(gateway)) revert Unauthorized();
        _;
    }

    constructor(address payable gatewayAddress, address liquidityManagerAddress, address _acceptedUSDC) {
        gateway = GatewayZEVM(gatewayAddress);
        liquidityManager = LiquidityManager(liquidityManagerAddress);
        acceptedUSDC = _acceptedUSDC;
    }

    function onCall(MessageContext calldata context, address zrc20, uint256 amount, bytes calldata message)
        external
        override
        onlyGateway
    {
        require(acceptedUSDC == zrc20, "Invalid token");
        
        (FunctionOptions option, bytes memory data) = abi.decode(message, (FunctionOptions, bytes));
        if (option == FunctionOptions.CREATE_OPTIONS) {
            _createOptions(data);
        }
    }

    function _createOptions(bytes memory data) internal {
        (OptionType optionType, uint256 strikePrice, uint256 currentPrice, uint256 size, uint256 expiry, address buyer)
        = abi.decode(data, (OptionType, uint256, uint256, uint256, uint256, address));
        uint256 maxPayout = _calculateMaxPayout(size);
        Options memory options = Options({
            optionType: optionType,
            maxPayout: maxPayout,
            strikePrice: strikePrice,
            currentPrice: currentPrice,
            size: size,
            buyer: buyer,
            createdAt: block.timestamp,
            expiry: expiry,
            isResolved: false
        });
        userOptions[optionId] = options;
        optionId++;
    }

    function _calculateMaxPayout(uint256 size) internal pure returns (uint256 payout) {
        payout = (size * PREMIUM_PER_SIZE) / 1e6;
    }
}
