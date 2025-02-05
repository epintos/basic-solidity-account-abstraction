-include .env

.PHONY: all test deploy

build :; forge build

test :; forge test

test-fork-sepolia :; @forge test --fork-url $(SEPOLIA_RPC_URL)

install :
	forge install foundry-rs/forge-std@v1.9.5 --no-commit && \
	forge install openzeppelin/openzeppelin-contracts@v5.2.0 --no-commit && \

deploy-sepolia :
	@forge script script/DeployMinimalAccount.s.sol:DeployMinimalAccount --rpc-url $(SEPOLIA_RPC_URL) --account $(SEPOLIA_ACCOUNT) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv

deploy-anvil :
	@forge script script/DeployMinimalAccount.s.sol:DeployMinimalAccount --rpc-url $(RPC_URL) --account $(ANVIL_ACCOUNT) --broadcast -vvvv --sender $(ANVIL_ACCOUNT_ADDRESS)
