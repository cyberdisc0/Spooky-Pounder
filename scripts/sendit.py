from brownie import (
    MyStrategy,
    TheVault,
    accounts,
)

from _setup.config import (
    WANT, 

    PERFORMANCE_FEE_GOVERNANCE,
    PERFORMANCE_FEE_STRATEGIST,
    WITHDRAWAL_FEE,
    MANAGEMENT_FEE,
)


def main():
    want = WANT


    acct = accounts.load('testWallet')
    vault = TheVault.deploy({'from': acct}, publish_source=True)


    vault.initialize(
        want,
        acct,
        acct,
        acct,
        acct,
        acct,
        acct,
        "",
        "",
        [
            PERFORMANCE_FEE_GOVERNANCE,
            PERFORMANCE_FEE_STRATEGIST,
            WITHDRAWAL_FEE,
            MANAGEMENT_FEE,
        ],
    )


    vault.setStrategist(acct, {"from": acct})
    # NOTE: TheVault starts unpaused

    strategy = MyStrategy.deploy({"from": acct}, publish_source=True)
    strategy.initialize(vault, [want])
    # NOTE: Strategy starts unpaused

    vault.setStrategy(strategy, {"from": acct})




