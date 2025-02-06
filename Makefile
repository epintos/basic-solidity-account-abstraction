-include .env

.PHONY: all test deploy

build :; forge build

test :; forge test

test-fork-sepolia :; @forge test --fork-url $(SEPOLIA_RPC_URL)

install :
	forge install foundry-rs/forge-std@v1.9.5 --no-commit && \
	forge install eth-infinitism/account-abstraction@v0.7.0 --no-commit && \
	forge install openzeppelin/openzeppelin-contracts@v5.2.0 --no-commit

deploy-sepolia :
	@forge script script/DeployMinimalAccount.s.sol:DeployMinimalAccount --rpc-url $(SEPOLIA_RPC_URL) --account $(SEPOLIA_ACCOUNT) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv

# Private key is for testing purposes only and matches the key in HelperConfig
deploy-anvil :
	@forge script script/DeployMinimalAccount.s.sol:DeployMinimalAccount --rpc-url $(RPC_URL) --broadcast -vvvv --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
