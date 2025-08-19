include .env

.PHONY: format test build deploy-mock-usdc-zeta deploy-mock-usdc-base deploy-mock-usdc-ethereum deploy-anchor-core deploy-anchor-client-base deploy-anchor-client-ethereum

format:
	forge fmt 

test:
	forge test

build:
	forge build

deploy-mock-usdc-zeta:
	forge create contracts/MockUSDC.sol:MockUSDC --rpc-url ${RPC_URL_ZETA} \
    --private-key ${PRIVATE_KEY} \
    --broadcast \
    --verify \
	--verifier blockscout \
	--verifier-url ${BLOCKSCOUT_VERIFIER_URL_ZETA} \

deploy-mock-usdc-arbitrum:
	forge create contracts/MockUSDC.sol:MockUSDC --rpc-url ${RPC_URL_ARBITRUM} \
	--private-key ${PRIVATE_KEY} \
	--broadcast \
	--verify \
	--verifier blockscout \
	--verifier-url ${BLOCKSCOUT_VERIFIER_URL_ARBITRUM} \

deploy-mock-usdc-ethereum:
	forge create contracts/MockUSDC.sol:MockUSDC --rpc-url ${RPC_URL_ETHEREUM} \
	--private-key ${PRIVATE_KEY} \
	--broadcast \
	--verify \
	--verifier blockscout \
	--verifier-url ${BLOCKSCOUT_VERIFIER_URL_ETHEREUM} \

deploy-anchor-core:
	forge create contracts/AnchorCore.sol:AnchorCore --rpc-url ${RPC_URL_ZETA} \
	--private-key ${PRIVATE_KEY} \
	--broadcast \
	--verify \
	--verifier blockscout \
	--verifier-url ${BLOCKSCOUT_VERIFIER_URL_ZETA} \
	--constructor-args ${GATEWAY_ZETA} ${USDC_ZETA} ${PYTH_ZETA}

deploy-anchor-client-arbitrum:
	forge create contracts/AnchorClient.sol:AnchorClient --rpc-url ${RPC_URL_ARBITRUM} \
	--private-key ${PRIVATE_KEY} \
	--broadcast \
	--verify \
	--verifier blockscout \
	--verifier-url ${BLOCKSCOUT_VERIFIER_URL_ARBITRUM} \
	--constructor-args ${USDC_ARBITRUM} ${ZRC20_USDC_ARBITRUM} ${GATEWAY_ARBITRUM} ${PYTH_ARBITRUM} ${ANCHOR_ADDRESS}

deploy-anchor-client-ethereum:
	forge create contracts/AnchorClient.sol:AnchorClient --rpc-url ${RPC_URL_ETHEREUM} \
	--private-key ${PRIVATE_KEY} \
	--broadcast \
	--verify \
	--verifier blockscout \
	--verifier-url ${BLOCKSCOUT_VERIFIER_URL_ETHEREUM} \
	--constructor-args ${USDC_ETHEREUM} ${ZRC20_USDC_ETHEREUM} ${GATEWAY_ETHEREUM} ${PYTH_ETHEREUM} ${ANCHOR_ADDRESS}
