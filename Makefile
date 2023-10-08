-include .env
test-mainnet:; forge test -vvvv --match-path test/unit/PerpetuEx.t.sol --fork-url "${MAINNET_RPC_URL}"
test-anvil:; forge test -vvvv --match-contract PerpetuExTestAnvil
coverage-mainnet:; forge coverage --fork-url ${MAINNET_RPC_URL} -vvvv
update-coverage:; forge coverage --report lcov; genhtml lcov.info -o report --branch-coverage --ignore-errors category