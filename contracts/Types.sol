// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

bytes32 constant BTC_PRICE_ID = 0xe62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43;
uint256 constant PREMIUM_PER_SIZE = 100_000_000;

enum OptionType {
    CALL,
    PUT
}

enum FunctionOptions {
    CREATE_OPTIONS,
    ADD_LIQUIDITY,
    REMOVE_LIQUIDITY,
    CLAIM_REWARD
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
    uint256 payout;
}
