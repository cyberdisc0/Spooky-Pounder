from brownie import accounts, interface 
from brownie import *

def main():

    # Constants 
    weth = interface.IERC20('0x74b23882a30290451A17c44f4F05243b6b58C76d')
    wbtc = interface.IERC20('0x321162Cd933E2Be498Cd2267a90534A804051b11')
    lp = interface.IERC20('0xEc454EdA10accdD66209C57aF8C12924556F3aBD')
    boo = interface.IERC20('0x841FAD6EAe12c286d1Fd18d1d525DFfA75C7EFFE')
    wftm = interface.IERC20('0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83')

    wbtc_address = wbtc.address
    weth_address = weth.address
    boo_address = boo.address
    wftm_address = wftm.address

    spooky_router = interface.IUniswapV2Router02('0x31F63A33141fFee63D4B26755430a390ACdD8a4d')
    farm = interface.IMasterChef('0x18b4f774fdC7BF685daeeF66c2990b1dDd9ea6aD') 

    me = accounts[0]
    whale_lp = '0x3f06b360fb8F8bf04D4C246dB21B3Fed23136f99'

    maxInt = 115792089237316195423570985008687907853269984665640564039457584007913129639935



    # check all balances are 0
    assert wbtc.balanceOf(me) == 0
    assert weth.balanceOf(me) == 0
    assert lp.balanceOf(me) == 0
    assert boo.balanceOf(me) == 0
    assert farm.userInfo(25, me)[0] == 0



    # Transfer funds to my account
    amount_lp = lp.balanceOf(whale_lp)
    print("lp whale balance: ", lp.balanceOf(whale_lp))
    
    lp.approve(me, amount_lp, {'from': whale_lp})
    lp.transferFrom(whale_lp, me, amount_lp, {'from': me})

    assert lp.balanceOf(me) > 0
    assert lp.balanceOf(me) == amount_lp

    print("my lp balance after whale transfer", lp.balanceOf(me))


    # Deposit to Farm
    assert farm.userInfo(25, me)[0] == 0
    assert farm.userInfo(25, me)[1] == 0

    lp.approve(farm, amount_lp,{'from': me})
    farm.deposit(25, amount_lp, {'from': me})

    assert farm.userInfo(25, me)[0] > 0
    assert farm.userInfo(25, me)[0] == amount_lp
    assert lp.balanceOf(me) == 0

    print("lps balance in farm", farm.userInfo(25, me)[0])
    print("boo rewards right after deposit: ", farm.userInfo(25, me)[1])

    # 1 day passes, accrue rewards
    chain.sleep(24*3600)
    chain.mine(1)

    assert farm.userInfo(25, me)[1] > 0
    
    print("boo rewards after 24 hours: ", farm.userInfo(25, me)[1])


    # withdraw boo rewards from farm
    assert lp.balanceOf(me) == 0
    assert boo.balanceOf(me) == 0

    farm.withdraw(25, 0, {'from': me})
    
    assert boo.balanceOf(me) > 0 
    assert lp.balanceOf(me) == 0 
    assert farm.userInfo(25, me)[0] == amount_lp

    print("boo rewards after withdrawing: ", boo.balanceOf(me))


    #swap rewards for lp assets
    amountboo = boo.balanceOf(me)
    boo.approve(spooky_router, maxInt, {'from': me})

    halfboo = amountboo*5000/10000

    spooky_router.swapExactTokensForTokens(halfboo, 1, [boo_address, wftm_address, wbtc_address], me, 1e20, {'from': me})
    spooky_router.swapExactTokensForTokens(halfboo, 1, [boo_address, wftm_address, weth_address], me, 1e20, {'from': me})


    #add more to liquidity pool
    wbtc.approve(spooky_router, maxInt, {'from': me})
    weth.approve(spooky_router, maxInt, {'from': me})

    amount_wbtc = wbtc.balanceOf(me)
    print("my wbtc balance after trading boo: ", amount_wbtc)
    amount_weth = weth.balanceOf(me)
    print("my weth balance after trading boo: ", amount_weth)

    assert lp.balanceOf(me) == 0
    spooky_router.addLiquidity( wbtc_address, weth_address, amount_wbtc, amount_weth, 1, 1, me, 1e20, {'from': me})
    assert lp.balanceOf(me) > 0

    print("wbtc balance after adding liquidity: ", wbtc.balanceOf(me))
    print("weth balance after adding liquidity: ", weth.balanceOf(me))
    
    
    # Deposit to farm
    lp.approve(farm, maxInt, {'from': me})

    amount_harvested_lp = lp.balanceOf(me)
    print('lp amount after harvesting and adding liquidity: ', amount_harvested_lp)

    balance_before = farm.userInfo(25, me)[0]
    farm.deposit(25, amount_harvested_lp, {'from': me})
    balance_after = farm.userInfo(25, me)[0]

    print("balance in farm before deposit: ", balance_before)
    print("balance in farm after deposit: ", balance_after)

    assert balance_after > balance_before 
    assert farm.userInfo(25, me)[0] == balance_before + amount_harvested_lp
    assert lp.balanceOf(me) == 0


    # Withdraw Everything from Farm 
    amount_to_withdraw = farm.userInfo(25, me)[0]

    farm.withdraw(25, amount_to_withdraw, {'from': me})

    assert lp.balanceOf(me) > 0 
    assert lp.balanceOf(me) == balance_before + amount_harvested_lp
    assert farm.userInfo(25, me)[0] == 0
