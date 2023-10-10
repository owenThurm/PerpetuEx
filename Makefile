-include .env
<<<<<<< ethcompass
test-mainnet:; forge test  -vvvv --match-path test/Ethereum_Compas/unit/MainNet.t.sol --fork-url "${MAINNET_RPC_URL}"
test-anvil:; forge test  -vvvv --match-contract Anvil
=======

single:; forge test --match-test testIncreaseCollateral1  -vv --fork-url "${MAINNET_RPC_URL}"

##Main net tests
test-mainnet:; forge test -vv --match-path test/Ethereum_Compas/unit/MainNet.t.sol --fork-url "${MAINNET_RPC_URL}"
>>>>>>> audit
coverage-mainnet:; forge coverage --fork-url ${MAINNET_RPC_URL} -vvvv
update-mainnet-coverage:; forge coverage --report lcov --fork-url ${MAINNET_RPC_URL}; genhtml lcov.info -o report --ignore-errors category

##Anvil tests
test-anvil:; forge test -vvvv --match-contract Anvil
coverage-anvil:; forge coverage -vvvv
update-anvil-coverage:; forge coverage --report lcov ; genhtml lcov.info -o report --ignore-errors category