-include .env
test-mainnet:; forge test --match-test testDepositAgain -vvvv --match-path test/Ethereum_Compas/unit/MainNet.t.sol --fork-url "${MAINNET_RPC_URL}"
test-anvil:; forge test --match-test testRemoveLiquidityWhilePnLisPostive -vvvv --match-contract Anvil
coverage-mainnet:; forge coverage --fork-url ${MAINNET_RPC_URL} -vvvv
update-mainnet-coverage:; forge coverage --report lcov --fork-url ${MAINNET_RPC_URL}; genhtml lcov.info -o report --ignore-errors category
update-anvil-coverage:; forge coverage --report lcov ; genhtml lcov.info -o report --ignore-errors category