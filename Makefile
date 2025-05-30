-include .env

.PHONY:; all test deploy

build :; forge build

test :; forge test

install :; forge install cyfrin/foundry-devops --no-commit && forge install foundry-rs/forge-std --no-commit && forge install openzeppelin/openzeppelin-contracts --no-commit

check-uri :
	@forge script script/Interactions.s.sol:CheckURI --rpc-url http://127.0.0.1:8545 -vvvv

mint-cava :
	@forge script script/Interactions.s.sol:MintBasicNFT --rpc-url http://127.0.0.1:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast -vvvv

deploy-cava-curtis :
	@forge script script/DeployCava.s.sol:DeployCava --rpc-url $(CURTIS_RPC_URL) --account defaultk2 --broadcast -vvvv

cavanft-verify-curtis :; forge verify-contract $(CURTIS_CAVA_CONTRACT_ADDRESS) src/CavaNFT.sol:CavaNFT --chain-id 33111 --verifier-url $(APESCAN_CURTIS_API_KEY)

deploy-cava-apechain :
	@forge script script/DeployCava.s.sol:DeployCava --rpc-url $(APECHAIN_RPC_URL) --account defaultk2 --broadcast -vvvv

cavanft-verify :; forge verify-contract $(CAVA_CONTRACT_ADDRESS) src/CavaNFT.sol:CavaNFT --chain-id 33139 --verifier-url $(APESCAN_API_KEY)

deploy-staking-curtis :
	@forge script script/DeployCavaStaking.s.sol:DeployCavaStaking --rpc-url $(CURTIS_RPC_URL) --account defaultk2 --broadcast -vvvv

cavastaking-verify-curtis :; forge verify-contract $(CURTIS_CAVA_STAKING_CONTRACT_ADDRESS) src/CavaStaking.sol:CavaStaking --chain-id 33111 --verifier-url $(APESCAN_CURTIS_API_KEY)

deploy-nft-mock-curtis :
	@forge script script/DeployMockNFT.s.sol:DeployMockNFT --rpc-url $(CURTIS_RPC_URL) --account defaultk2 --broadcast -vvvv

nft-mock-verify-curtis :; forge verify-contract $(MINGLE_CURTIS) src/NFT.sol:NFT --chain-id 33111 --verifier-url $(APESCAN_CURTIS_API_KEY)

deploy-staking :
	@forge script script/DeployCavaStaking.s.sol:DeployCavaStaking --rpc-url $(APECHAIN_RPC_URL) --account defaultk2 --broadcast -vvvv

cavastaking-verify :; forge verify-contract $(CAVA_STAKING_CONTRACT_ADDRESS) src/CavaStaking.sol:CavaStaking --chain-id 33139 --verifier-url $(APESCAN_API_KEY)

deploy-mingles-curtis :
	@forge script script/DeployBasicNFT.s.sol:DeployMingles --rpc-url $(CURTIS_RPC_URL) --account defaultk2 --broadcast --verify --etherscan-api-key $(APESCAN_API_KEY) -vvvv

deploy-gsape-curtis :
	@forge script script/DeployBasicNFT.s.sol:DeployGS --rpc-url $(CURTIS_RPC_URL) --account defaultk2 --broadcast --verify --etherscan-api-key $(APESCAN_API_KEY) -vvvv

deploy-ape :
	@forge script script/DeployCava.s.sol:DeployCava --rpc-url $(APECHAIN_RPC_URL) --account defaultk2 --broadcast --verify --etherscan-api-key $(APESCAN_API_KEY) -vvvv

deploy-game-curtis :
	@forge script script/DeployGame.s.sol:DeployGameWithContracts --rpc-url $(CURTIS_RPC_URL) --account defaultk2 --broadcast -vvvv

sepolia-json :; forge verify-contract $(CAVA_CONTRACT_ADDRESS) src/Cava.sol:Cava --etherscan-api-key $(ETHERSCAN_API_KEY) --rpc-url $(SEPOLIA_RPC_URL) --show-standard-json-input > json.json

mingles-verify :; forge verify-contract --watch --constructor-args $(ENCODED_MINGLE_CONSTRUCTOR) $(MINGLE_CURTIS) src/nft.sol:NFT --etherscan-api-key $(APESCAN_CURTIS_API_KEY) --rpc-url $(CURTIS_RPC_URL)

mingles-verify-curtis :; forge verify-contract --constructor-args $(ENCODED_MINGLE_CONSTRUCTOR) $(MINGLE_CURTIS) src/nft.sol:NFT --chain-id 33111 --verifier-url $(APESCAN_CURTIS_API_KEY)

gs-verify-curtis :; forge verify-contract --constructor-args $(ENCODED_GS_CONSTRUCTOR) $(GS_CURTIS) src/nft.sol:NFT --chain-id 33111 --verifier-url $(APESCAN_CURTIS_API_KEY)

game-verify-curtis :; forge verify-contract --constructor-args $(ENCODED_MINGLE_GAME_CONSTRUCTOR) $(CURTIS_GAME_CONTRACT_ADDRESS) src/NftGame.sol:NftGame --chain-id 33111 --verifier-url $(APESCAN_CURTIS_API_KEY)

mingles-curtis-json :; forge verify-contract $(MINGLE_CURTIS) src/nft.sol:NFT --etherscan-api-key $(APESCAN_API_KEY) --rpc-url $(CURTIS_RPC_URL) --watch #--show-standard-json-input > json.json

coverage-report :; forge coverage --report debug > coverage.txt

coverage :; forge coverage

mint-mingle-curtis :
	@forge script script/Interactions.s.sol:MintBasicNFT --rpc-url $(CURTIS_RPC_URL) --account defaultk2 --broadcast -vvvv

mingle-balanceof :; cast call $(MINGLE_CURTIS) "balanceOf(address)(uint256)" 0xca067E20db2cDEF80D1c7130e5B71C42c0305529 --rpc-url $(CURTIS_RPC_URL) -vvvv