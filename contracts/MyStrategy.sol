// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;


import "@openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin-contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable/math/MathUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";

import {BaseStrategy} from "@badger-finance/BaseStrategy.sol";
import {IMasterChef} from "../interfaces/spooky/IMasterChef.sol";
import {IUniswapV2Router02} from "../interfaces/spooky/IUniswapV2Router02.sol";


contract MyStrategy is BaseStrategy {
// address public want; // Inherited from BaseStrategy
    // address public lpComponent; // Token that represents ownership in a pool, not always used
    // address public reward; // Token we farm


    address constant REWARD = 0x841FAD6EAe12c286d1Fd18d1d525DFfA75C7EFFE; // boo

    address constant WETH = 0x74b23882a30290451A17c44f4F05243b6b58C76d;
    address constant WBTC = 0x321162Cd933E2Be498Cd2267a90534A804051b11;
    address constant WFTM = 0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83;

    address constant SPOOKYSWAP_ROUTER = 0x31F63A33141fFee63D4B26755430a390ACdD8a4d;
    address constant FARM = 0x18b4f774fdC7BF685daeeF66c2990b1dDd9ea6aD;

    uint256 constant PID = 25;


    /// @dev Initialize the Strategy with security settings as well as tokens
    /// @notice Proxies will set any non constant variable you declare as default value
    /// @dev add any extra changeable variable at end of initializer as shown
    function initialize(address _vault, address[1] memory _wantConfig) public initializer {
        __BaseStrategy_init(_vault);
        /// @dev Add config here
        want = _wantConfig[0];
        
        // If you need to set new values that are not constants, set them like so
        // stakingContract = 0x79ba8b76F61Db3e7D994f7E384ba8f7870A043b7;

        // If you need to do one-off approvals do them here like so
        IERC20Upgradeable(want).safeApprove(
            address(FARM),
            type(uint256).max
        );

        IERC20Upgradeable(REWARD).safeApprove(
            address(SPOOKYSWAP_ROUTER),
            type(uint256).max
        );

        IERC20Upgradeable(WBTC).safeApprove(
            address(SPOOKYSWAP_ROUTER),
            type(uint256).max
        );

        IERC20Upgradeable(WETH).safeApprove(
            address(SPOOKYSWAP_ROUTER),
            type(uint256).max
        );
    }
    
    /// @dev Return the name of the strategy
    function getName() external pure override returns (string memory) {
        return "Spookyswap Pounder - WBTC/WETH LP";
    }

    /// @dev Return a list of protected tokens
    /// @notice It's very important all tokens that are meant to be in the strategy to be marked as protected
    /// @notice this provides security guarantees to the depositors they can't be sweeped away
    function getProtectedTokens() public view virtual override returns (address[] memory) {
        address[] memory protectedTokens = new address[](2);
        protectedTokens[0] = want;
        protectedTokens[1] = REWARD;
        return protectedTokens;
    }

    /// @dev Deposit `_amount` of want, investing it to earn yield
    function _deposit(uint256 _amount) internal override {
        // Add code here to invest `_amount` of want to earn yield 
        IMasterChef(FARM).deposit(PID, _amount);
    }

    /// @dev Withdraw all funds, this is used for migrations, most of the time for emergency reasons
    function _withdrawAll() internal override {
        // Add code here to unlock all available funds

        IMasterChef(FARM).withdraw(PID, balanceOfPool());

    }

    /// @dev Withdraw `_amount` of want, so that it can be sent to the vault / depositor
    /// @notice just unlock the funds and return the amount you could unlock
    function _withdrawSome(uint256 _amount) internal override returns (uint256) {
        // Add code here to unlock / withdraw `_amount` of tokens to the withdrawer
        // If there's a loss, make sure to have the withdrawer pay the loss to avoid exploits
        // Socializing loss is always a bad idea

        if (_amount > balanceOfPool()) {
            _amount = balanceOfPool();
        }

        IMasterChef(FARM).withdraw(PID, _amount);

        return _amount;
    }


    /// @dev Does this function require `tend` to be called?
    function _isTendable() internal override pure returns (bool) {
        return true; // Change to true if the strategy should be tended
    }

    function _harvest() internal override returns (TokenAmount[] memory harvested) {
        // No-op as we don't do anything with funds
        // use autoCompoundRatio here to convert rewards to want ...

        IMasterChef(FARM).withdraw(PID, 0); // the withdraw function always withdraws all of the rewards + a specified amount of lps. here we only want rewards, so lp amount = 0
        
        uint256 allRewards = IERC20Upgradeable(REWARD).balanceOf(address(this));

        uint256 halfOfRewards = allRewards.mul(5000).div(10000);

        address[] memory path1 = new address[](3); // path from BOO to WBTC
        path1[0] = REWARD;
        path1[1] = WFTM;
        path1[2] = WBTC;

        address[] memory path2 = new address[](3); // path from BOO to WETH
        path2[0] = REWARD;
        path2[1] = WFTM;
        path2[2] = WETH;

        uint256 beforeWant = IERC20Upgradeable(want).balanceOf(address(this));

        IUniswapV2Router02(SPOOKYSWAP_ROUTER).swapExactTokensForTokens(halfOfRewards, 0, path1, address(this), block.timestamp);
        IUniswapV2Router02(SPOOKYSWAP_ROUTER).swapExactTokensForTokens(halfOfRewards, 0, path2, address(this), block.timestamp);

        uint256 amount_wbtc = IERC20Upgradeable(WBTC).balanceOf(address(this));
        uint256 amount_weth = IERC20Upgradeable(WETH).balanceOf(address(this));

        IUniswapV2Router02(SPOOKYSWAP_ROUTER).addLiquidity(WBTC, WETH, amount_wbtc, amount_weth, 0, 0, address(this), block.timestamp);

        uint256 afterWant = IERC20Upgradeable(want).balanceOf(address(this));

        // Report profit for the want increase (NOTE: We are not getting perf fee on AAVE APY with this code)
        uint256 wantHarvested = afterWant.sub(beforeWant);
        _reportToVault(wantHarvested);

        // Remaining balance to emit to tree
        uint256 rewardEmitted = IERC20Upgradeable(REWARD).balanceOf(address(this)); 
        _processExtraToken(REWARD, rewardEmitted);


                        

        // Return the same value for APY and offChain automation
        harvested = new TokenAmount[](2);
        harvested[0] = TokenAmount(want, wantHarvested);
        harvested[1] = TokenAmount(REWARD, rewardEmitted);
        return harvested;
    }


    // Example tend is a no-op which returns the values, could also just revert
    function _tend() internal override returns (TokenAmount[] memory tended){
        uint256 balanceToTend = balanceOfWant();
        _deposit(balanceToTend);


        // Return all tokens involved for offChain tracking and automation
        tended = new TokenAmount[](2);
        tended[0] = TokenAmount(want, balanceToTend);
        tended[2] = TokenAmount(REWARD, 0); 
        return tended;
    }

    /// @dev Return the balance (in want) that the strategy has invested somewhere
    function balanceOfPool() public view override returns (uint256) {
        // Change this to return the amount of want invested in another protocol
        (uint256 farmBalance, uint256 accruedRewards) = IMasterChef(FARM).userInfo(PID, address(this));
        return farmBalance;
    }

    /// @dev Return the balance of rewards that the strategy has accrued
    /// @notice Used for offChain APY and Harvest Health monitoring
    function balanceOfRewards() external view override returns (TokenAmount[] memory rewards) {
        
        (uint256 farmBalance, uint256 accruedRewards) = IMasterChef(FARM).userInfo(PID, address(this));
        
        rewards = new TokenAmount[](1);
        rewards[1] = TokenAmount(REWARD, accruedRewards); 
        return rewards;
    }
}
