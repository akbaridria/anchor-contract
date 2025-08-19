// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@zetachain/protocol-contracts/contracts/zevm/GatewayZEVM.sol";
import "@zetachain/protocol-contracts/contracts/zevm/interfaces/IZRC20.sol";
import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";
import "./MockUSDC.sol";
import "./LiquidityManager.sol";
import "./Types.sol";

contract AnchorCore is UniversalContract {
    GatewayZEVM public immutable gateway;
    LiquidityManager public immutable liquidityManager;
    MockUSDC public immutable usdc;
    IPyth public immutable pyth;

    uint256 constant RESOLVER_FEE = 100; // 1%
    uint256 constant PLATFORM_FEE = 100; // 1%
    uint256 constant DEFAULT_GAS_LIMIT = 3_000_000;

    uint256 optionId;

    mapping(uint256 => Options) public detailOptions;
    mapping(address => uint256[]) public userOptionIds;

    event OptionCreated(
        uint256 optionId, address buyer, uint256 premium, uint256 strikePrice, uint256 size, uint256 expiry
    );
    event LiquidityAdded(uint256 amount, address provider);
    event LiquidityRemoved(uint256 amount, address provider);
    event OptionsResolved(uint256 optionId, uint256 payout, address resolver);
    event RewardClaimed(uint256 optionId, uint256 payout, address user);

    error Unauthorized();
    error InsufficientLiquidity();
    error OptionsNotExpiredOrResolved();
    error OptionDoesNotExist();
    error InsufficientBalance();
    error OptionsExpiryLessThanCurrent();
    error InvalidStrikePrice();

    modifier onlyGateway() {
        if (msg.sender != address(gateway)) revert Unauthorized();
        _;
    }

    modifier checkStrikePrice(uint256 strikePrice, uint256 currentPrice, OptionType optionType) {
        if (optionType == OptionType.CALL && strikePrice < currentPrice) {
            revert InvalidStrikePrice();
        } else if (optionType == OptionType.PUT && strikePrice > currentPrice) {
            revert InvalidStrikePrice();
        }
        _;
    }

    modifier checkOptionOwnership(uint256 id, address user) {
        if (detailOptions[id].buyer != user) revert Unauthorized();
        _;
    }

    modifier checkOption(uint256 id) {
        if (detailOptions[id].buyer == address(0)) revert OptionDoesNotExist();
        _;
    }

    constructor(address payable _gatewayAddress, address _usdcAddress, address _pythAddress) {
        gateway = GatewayZEVM(_gatewayAddress);
        liquidityManager = new LiquidityManager();
        usdc = MockUSDC(_usdcAddress);
        pyth = IPyth(_pythAddress);
    }

    function onCall(MessageContext calldata, address, uint256, bytes calldata message)
        external
        override
        onlyGateway
    {
        (FunctionOptions option, bytes memory data) = abi.decode(message, (FunctionOptions, bytes));
        if (option == FunctionOptions.CREATE_OPTIONS) {
            _createOptions(data, true);
        }
        if (option == FunctionOptions.ADD_LIQUIDITY) {
            _addLiquidity(data);
        }
        if (option == FunctionOptions.REMOVE_LIQUIDITY) {
            _removeLiquidity(data);
        }
        if (option == FunctionOptions.CLAIM_REWARD) {
            _claimReward(data);
        }
    }

    function createOptions(
        bytes[] calldata priceUpdateData,
        OptionType optionType,
        uint256 expiry,
        uint256 premium,
        uint256 size,
        uint256 strikePrice
    ) external payable {
        uint256 minimumPremium = _calculatePremium(size);
        if (premium < minimumPremium) revert InsufficientBalance();
        if (block.timestamp > expiry) revert OptionsExpiryLessThanCurrent();

        usdc.transferFrom(msg.sender, address(this), premium);

        uint256 currentPrice = _getBtcPrice(priceUpdateData);
        bytes memory data = abi.encode(optionType, premium, strikePrice, currentPrice, size, expiry, msg.sender);
        _createOptions(data, false);
    }

    function addLiquidity(uint256 amount) external {
        bytes memory data = abi.encode(amount, msg.sender);
        _addLiquidity(data);
    }

    function removeLiquidity(uint256 amount) external {
        bytes memory data = abi.encode(amount, msg.sender);
        _removeLiquidity(data);
    }

    function _getBtcPrice(bytes[] calldata priceUpdateData) internal returns (uint256) {
        uint256 fee = pyth.getUpdateFee(priceUpdateData);
        pyth.updatePriceFeeds{value: fee}(priceUpdateData);
        PythStructs.Price memory currentPrice = pyth.getPriceNoOlderThan(BTC_PRICE_ID, 30);
        return uint256(uint64(currentPrice.price));
    }

    function _createOptions(bytes memory data, bool isCrossChain) internal {
        (
            OptionType optionType,
            uint256 premium,
            uint256 strikePrice,
            uint256 currentPrice,
            uint256 size,
            uint256 expiry,
            address buyer
        ) = abi.decode(data, (OptionType, uint256, uint256, uint256, uint256, uint256, address));
        uint256 maxPayout = _calculateMaxPayout(size, currentPrice, strikePrice);
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
            isResolved: false,
            payout: 0
        });
        detailOptions[optionId] = options;
        userOptionIds[buyer].push(optionId);
        emit OptionCreated(optionId, buyer, premium, strikePrice, size, expiry);
        optionId++;

        if (isCrossChain) {
            usdc.mint(premium);
        }
        liquidityManager.lockLiquidity(maxPayout);
    }

    function _addLiquidity(bytes memory data) internal {
        (uint256 amount, address user) = abi.decode(data, (uint256, address));
        liquidityManager.addLiquidity(user, amount);
        emit LiquidityAdded(amount, user);
    }

    function _removeLiquidity(bytes memory data) internal {
        (uint256 amount, address user, address zrc20, address destinationAddress) =
            abi.decode(data, (uint256, address, address, address));
        uint256 availLiquidity = liquidityManager.getAvailableLiquidity();
        if (amount > availLiquidity) revert InsufficientLiquidity();
        liquidityManager.removeLiquidity(user, amount);
        bytes memory message = abi.encode(user, amount);
        _sendMessage(user, zrc20, destinationAddress, message);
        emit LiquidityRemoved(amount, user);
    }

    function resolveOptions(uint256 id, bytes[] calldata priceUpdateData) external payable checkOption(id) {
        uint256 currentPrice = _getBtcPrice(priceUpdateData);

        Options storage options = detailOptions[id];

        if (options.expiry > block.timestamp || options.isResolved) {
            revert OptionsNotExpiredOrResolved();
        }

        options.isResolved = true;

        // calculate if user win
        uint256 intrinsicValue =
            _calculateIntrinsicValue(options.optionType, options.strikePrice, currentPrice, options.size);
        // calculate resolverfee
        uint256 resolverFee = _calculateResolverFee(options.premium);
        // unlock liquidity
        liquidityManager.unlockLiquidity(options.maxPayout);
        // calculate realpayout
        uint256 payout = options.maxPayout < intrinsicValue ? options.maxPayout : intrinsicValue;
        options.payout = payout + options.premium - resolverFee;
        // transfer to resolver as reward
        usdc.transfer(msg.sender, resolverFee);

        // calculate pnl
        int256 pnl = _calculatePnl(resolverFee, payout, options.premium);
        liquidityManager.distributePnL(pnl);

        emit OptionsResolved(id, payout, msg.sender);
    }

    function claimReward(uint256 id) external checkOption(id) checkOptionOwnership(id, msg.sender) {
        Options storage options = detailOptions[id];
        usdc.transfer(msg.sender, options.payout);
        emit RewardClaimed(id, options.payout, msg.sender);
    }

    function _claimReward(bytes memory data) internal {
        (address user, address destinationAddress, address zrc20, uint256 id) =
            abi.decode(data, (address, address, address, uint256));
        Options storage options = detailOptions[id];
        if (options.buyer != user) revert Unauthorized();
        if (!options.isResolved) revert OptionsNotExpiredOrResolved();
        bytes memory message = abi.encode(user, options.payout);
        _sendMessage(user, zrc20, destinationAddress, message);
        options.payout = 0;
        emit RewardClaimed(id, options.payout, user);
    }

    function _sendMessage(address user, address zrc20, address destinationAddress, bytes memory message) internal {
        CallOptions memory callOptions = CallOptions({gasLimit: DEFAULT_GAS_LIMIT, isArbitraryCall: false});

        RevertOptions memory revertOptions = RevertOptions({
            revertAddress: user,
            callOnRevert: false,
            abortAddress: address(0),
            revertMessage: "",
            onRevertGasLimit: 0
        });
        (address gasZRC20, uint256 gasFee) = IZRC20(zrc20).withdrawGasFeeWithGasLimit(DEFAULT_GAS_LIMIT);
        IZRC20(gasZRC20).approve(address(gateway), gasFee);
        gateway.call(abi.encodePacked(destinationAddress), zrc20, message, callOptions, revertOptions);
    }

    function _calculatePnl(uint256 resolverFee, uint256 intrinsicValue, uint256 premium)
        internal
        pure
        returns (int256)
    {
        if (intrinsicValue == 0) {
            return int256(premium) - int256(resolverFee);
        }

        return -int256(intrinsicValue);
    }

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

    function _calculateMaxPayout(uint256 size, uint256 currentPrice, uint256 strikePrice)
        internal
        pure
        returns (uint256)
    {
        if (currentPrice > strikePrice) {
            // PUT options
            return (size * (currentPrice - strikePrice)) / 1e5;
        }
        return (size * (strikePrice - currentPrice)) / 1e5;
    }

    function _calculatePremium(uint256 size) internal pure returns (uint256) {
        return (size * PREMIUM_PER_SIZE) / 1e3;
    }

    function getTotalLiquidity() external view returns (uint256, uint256) {
        return (liquidityManager.getTotalLiquidity(), liquidityManager.getAvailableLiquidity());
    }

    function getProviderBalance(address _user) external view returns (uint256) {
        return liquidityManager.getProviderBalance(_user);
    }

    receive() external payable {}
    fallback() external payable {}
}
