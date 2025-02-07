-include .env

.PHONY: all test deploy

build :; forge build

test :; forge test

test-fork-sepolia :; @forge test --fork-url $(SEPOLIA_RPC_URL)

install :
	forge install foundry-rs/forge-std@v1.9.5 --no-commit && \
	forge install eth-infinitism/account-abstraction@v0.7.0 --no-commit && \
	forge install openzeppelin/openzeppelin-contracts@v5.2.0 --no-commit && \
	forge install cyfrin/foundry-era-contracts@0.0.3 --no-commit

# Private key is for testing purposes only and matches the key in HelperConfig
deploy-anvil :
	@forge script script/DeployMinimalAccount.s.sol:DeployMinimalAccount --rpc-url $(RPC_URL) --broadcast -vvvv --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# SEPOLIA_ACCOUNT is the wallet with BURNER_WALLET address
deploy-arbitrum-sepolia :
	@forge script script/DeployMinimalAccount.s.sol:DeployMinimalAccount --rpc-url $(ARBITRUM_SEPOLIA_RPC_URL) --sender $(BURNER_WALLET) --account ${SEPOLIA_ACCOUNT} --broadcast -vvvv --verify

arbitrum-sendpacked-user-op :
	@forge script script/SendPackedUserOp.s.sol:SendPackedUserOp --rpc-url $(ARBITRUM_SEPOLIA_RPC_URL) --sender $(BURNER_WALLET) --account ${SEPOLIA_ACCOUNT} --broadcast -vvvv


