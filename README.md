
# Spookswap Compounder WBTC-WETH

This is an auto compounder using Badger’s vault strategy brownie mix. This is for the WBTC-WETH LP on Spookyswap on Fantom. Not all tests will pass, as many of them use Badger’s strategy resolver, which does not handle LPs held in staking contracts. I have written a test called pound.py that runs through the strategy's flow
