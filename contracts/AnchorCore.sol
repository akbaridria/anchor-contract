// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@zetachain/protocol-contracts/contracts/zevm/GatewayZEVM.sol";
import "./MockUSDC.sol";
import "./LiquidityManager.sol";

// this is the core contract that will be deployed on zeta-chain
// since we need huge number of usdc for options trading, we will use a mock usdc contract
// thats why we need another contract that will be deployed on connected chain
// and we call it AnchorClient contract
// in real scenario, only this contract that we will be deployed.

contract AnchorCore is UniversalContract {
    GatewayZEVM public immutable gateway;
    LiquidityManager public immutable liquidityManager;
    MockUSDC public immutable usdc;

    enum OptionType {
        CALL,
        PUT
    }

    enum FunctionOptions {
        CREATE_OPTIONS,
        ADD_LIQUIDITY,
        REMOVE_LIQUIDITY,
        RESOLVE_OPTIONS
    }

    struct Options {
        OptionType optionType;
        uint256 premium;
        uint256 maxPayout;
        uint256 strikePrice;
        uint256 currentPrice;
        uint256 size;
        address buyer;
        uint256 createdAt;
        uint256 expiry;
        bool isResolved;
    }

    uint256 constant RESOLVER_FEE = 100; // 1%

    uint256 optionId;

    mapping(uint256 => Options) public detailOptions;
    mapping(address => uint256[]) public userOptionIds;

    error Unauthorized();
    error InsufficientLiquidity();
    error OptionsNotExpiredOrResolved();
    error OptionDoesNotExist();

    modifier onlyGateway() {
        if (msg.sender != address(gateway)) revert Unauthorized();
        _;
    }

    constructor(address payable _gatewayAddress, address _liquidityManagerAddress, address _usdcAddress) {
        gateway = GatewayZEVM(_gatewayAddress);
        liquidityManager = LiquidityManager(_liquidityManagerAddress);
        usdc = MockUSDC(_usdcAddress);
    }

    function onCall(MessageContext calldata context, address zrc20, uint256 amount, bytes calldata message)
        external
        override
        onlyGateway
    {
        (FunctionOptions option, bytes memory data) = abi.decode(message, (FunctionOptions, bytes));
        if (option == FunctionOptions.CREATE_OPTIONS) {
            _createOptions(data);
        }
    }

    function _createOptions(bytes memory data) internal {
        (
            OptionType optionType,
            uint256 premium,
            uint256 strikePrice,
            uint256 currentPrice,
            uint256 size,
            uint256 expiry,
            address buyer
        ) = abi.decode(data, (OptionType, uint256, uint256, uint256, uint256, uint256, address));
        uint256 maxPayout = _calculateMaxPayout(size, currentPrice);
        Options memory options = Options({
            optionType: optionType,
            premium: premium,
            maxPayout: maxPayout,
            strikePrice: strikePrice,
            currentPrice: currentPrice,
            size: size,
            buyer: buyer,
            createdAt: block.timestamp,
            expiry: expiry,
            isResolved: false
        });
        detailOptions[optionId] = options;
        userOptionIds[buyer].push(optionId);
        optionId++;

        usdc.mint(premium);
        liquidityManager.lockLiquidity(maxPayout);
    }

    function _addLiquidity(bytes memory data) internal {
        (uint256 amount, address user) = abi.decode(data, (uint256, address));
        liquidityManager.addLiquidity(user, amount);
    }

    function _removeLiquidity(bytes memory data) internal {
        (uint256 amount, address user) = abi.decode(data, (uint256, address));
        uint256 availLiquidity = liquidityManager.getAvailableLiquidity();
        if (amount > availLiquidity) revert InsufficientLiquidity();
        liquidityManager.removeLiquidity(user, amount);
    }

    function _resolveOptions(bytes memory data, address zrc20) internal {
        (uint256 id, address resolver, uint256 currentPrice, address destinationAddress) =
            abi.decode(data, (uint256, address, uint256, address));
        Options storage options = detailOptions[id];

        if (options.buyer == address(0)) {
            revert OptionDoesNotExist();
        }

        if (options.expiry > block.timestamp || options.isResolved) {
            revert OptionsNotExpiredOrResolved();
        }

        options.isResolved = true;

        // calculate if user win
        uint256 intrinsicValue =
            _calculateIntrinsicValue(options.optionType, options.strikePrice, currentPrice, options.size);
        uint256 resolverFee = _calculateResolverFee(options.premium);
        liquidityManager.unlockLiquidity(options.maxPayout);

        if (intrinsicValue == 0) {}
        // send message to the connected chain with the amount for the resolver
        // and the amount for the user if win.
    }

    function _sendMessageWithReward() internal {}

    function _calculateResolverFee(uint256 premium) internal pure returns (uint256) {
        return (premium * RESOLVER_FEE) / 1e3;
    }

    function _calculateIntrinsicValue(OptionType optionType, uint256 strikePrice, uint256 currentPrice, uint256 size)
        internal
        pure
        returns (uint256)
    {
        uint256 diff;
        if (optionType == OptionType.CALL) {
            diff = currentPrice > strikePrice ? currentPrice - strikePrice : 0;
        } else {
            diff = strikePrice > currentPrice ? strikePrice - currentPrice : 0;
        }
        // diff has 8 decimals, size has 3 decimals, USDC has 6 decimals
        // (diff * size) / 1e5 gives USDC 6 decimals
        return (diff * size) / 1e5;
    }

    function _calculateMaxPayout(uint256 size, uint256 currentPrice) internal pure returns (uint256) {
        // Calculate max payout in USDC (6 decimals)
        // size has 3 decimals (1e3), currentPrice has 8 decimals (1e8), USDC has 6 decimals (1e6)
        // Formula: (size * currentPrice) / (1e3 * 1e8 / 1e6) = (size * currentPrice) / 1e5
        return (size * currentPrice) / 1e5;
    }
}
