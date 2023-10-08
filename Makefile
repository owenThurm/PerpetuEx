-include .env
test-mainnet:; forge test -vvvv --match-path test/Ethereum_Compas/unit/EthereumCompassUnit.t.sol --fork-url "${MAINNET_RPC_URL}"
test-anvil:; forge test -vvvv --match-contract PerpetuExTestAnvil
coverage-mainnet:; forge coverage --fork-url ${MAINNET_RPC_URL} -vvvv
update-coverage:; forge coverage --report lcov --fork-url ${MAINNET_RPC_URL}; genhtml lcov.info -o report --ignore-errors category