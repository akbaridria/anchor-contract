// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "./MockUSDC.sol";
import "@zetachain/protocol-contracts/contracts/evm/GatewayEVM.sol";
import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";
import "./Types.sol";

contract AnchorClient {
    MockUSDC public immutable usdc;
    GatewayEVM public immutable gateway;
    IPyth public immutable pyth;
    address public immutable zrc20Usdc;
    address public immutable universal;

    error Unauthorized();

    modifier onlyGateway() {
        if (msg.sender != address(gateway)) revert Unauthorized();
        _;
    }

    constructor(address _usdc, address _zrc20Usdc, address payable _gateway, address _pyth, address _universal) {
        usdc = MockUSDC(_usdc);
        zrc20Usdc = _zrc20Usdc;
        gateway = GatewayEVM(_gateway);
        pyth = IPyth(_pyth);
        universal = _universal;
    }

    function createOptions(
        bytes[] calldata priceUpdateData,
        OptionType optionType,
        uint256 strikePrice,
        uint256 size,
        uint256 expiry
    ) external payable {
        uint256 currentPrice = _getBtcPrice(priceUpdateData);
        uint256 premium = _calculatePremium(size);
        usdc.transferFrom(msg.sender, address(this), premium);
        bytes memory data = abi.encode(optionType, premium, strikePrice, currentPrice, size, expiry, msg.sender);
        bytes memory message = abi.encode(FunctionOptions.CREATE_OPTIONS, data);
        _sendMessage(message);
    }

    function _sendMessage(bytes memory message) internal {
        RevertOptions memory revertOptions = RevertOptions({
            revertAddress: msg.sender,
            callOnRevert: false,
            abortAddress: address(0),
            revertMessage: "",
            onRevertGasLimit: 0
        });
        gateway.call(universal, message, revertOptions);
    }

    function _getBtcPrice(bytes[] calldata priceUpdateData) internal returns (uint256) {
        uint256 fee = pyth.getUpdateFee(priceUpdateData);
        pyth.updatePriceFeeds{value: fee}(priceUpdateData);
        PythStructs.Price memory currentPrice = pyth.getPriceNoOlderThan(BTC_PRICE_ID, 30);
        return uint256(uint64(currentPrice.price));
    }

    function _calculatePremium(uint256 size) internal pure returns (uint256) {
        return (size * PREMIUM_PER_SIZE) / 1e3;
    }

    function addLiquidity(uint256 amount) external {
        usdc.transferFrom(msg.sender, address(this), amount);
        bytes memory data = abi.encode(amount, msg.sender);
        bytes memory message = abi.encode(FunctionOptions.ADD_LIQUIDITY, data);
        _sendMessage(message);
    }

    function removeLiquidity(uint256 amount) external {
        bytes memory data = abi.encode(amount, msg.sender, zrc20Usdc, address(this));
        bytes memory message = abi.encode(FunctionOptions.REMOVE_LIQUIDITY, data);
        _sendMessage(message);
    }

    function claimReward(uint256 id) external {
        bytes memory data = abi.encode(msg.sender, address(this), zrc20Usdc, id);
        bytes memory message = abi.encode(FunctionOptions.CLAIM_REWARD, data);
        _sendMessage(message);
    }

    receive() external payable {}
    fallback() external payable {}
}
