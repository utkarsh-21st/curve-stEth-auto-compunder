// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../common/StratFeeManager.sol";
import "../common/StringUtils.sol";
import "../common/GasFeeThrottler.sol";

import "../interfaces/IPool.sol";
import "../interfaces/IGauge.sol";
import "../interfaces/IMinter.sol";
import "../interfaces/IWNative.sol";

contract Strategy is StratFeeManager, GasFeeThrottler {
    using SafeERC20 for IERC20;

    // Tokens used
    IERC20 public native;
    address public want;
    IERC20 public lpReceipt;
    address public lpToken0;
    address public lpToken1;
    IERC20 public reward1;
    IERC20 public reward2;

    // Third party contracts
    IPool public pool;
    IPool public reward1Pool;
    IPool public reward2Pool;
    IGauge public gauge;
    IMinter public minter;

    bool public harvestOnDeposit;
    uint256 public lastHarvest;
    string public pendingRewardsFunctionName;

    constructor(
        address _pool,
        address _reward1Pool,
        address _reward2Pool,
        address _gauge,
        address _minter,
        address _feeRecipient
    ) StratFeeManager(_feeRecipient) {
        pool = IPool(_pool);
        reward1Pool = IPool(_reward1Pool);
        reward2Pool = IPool(_reward2Pool);
        gauge = IGauge(_gauge);
        minter = IMinter(_minter);

        native = IERC20(reward1Pool.coins(0));
        want = pool.coins(1);
        lpReceipt = IERC20(pool.lp_token());
        reward1 = IERC20(reward1Pool.coins(1));
        reward2 = IERC20(reward2Pool.coins(1));

        _giveAllowances();
    }

    // puts the funds to work
    function deposit() public whenNotPaused {
        uint256 wantBalance = IERC20(want).balanceOf(address(this));
        if (wantBalance > 0) {
            zapWantToLpReceipt(wantBalance);
        }
        uint256 lpReceiptBalance = lpReceipt.balanceOf(address(this));
        if (lpReceiptBalance > 0) {
            gauge.deposit(lpReceiptBalance);
        }
    }

    function withdraw(uint256 _amount) external {
        require(msg.sender == vault, "!vault");

        uint256 wantBal = IERC20(want).balanceOf(address(this));

        if (wantBal < _amount) {
            uint256[2] memory tokensToWithdraw = [0, _amount - wantBal];
            uint256 lpReceiptToWithdraw = (pool.calc_token_amount(
                tokensToWithdraw,
                false
            ) * 110) / 100;

            if (lpReceipt.balanceOf(address(this)) < lpReceiptToWithdraw) {
                lpReceiptToWithdraw =
                    lpReceiptToWithdraw -
                    lpReceipt.balanceOf(address(this));
                if (gauge.balanceOf(address(this)) < lpReceiptToWithdraw)
                    lpReceiptToWithdraw = gauge.balanceOf(address(this));
                gauge.withdraw(lpReceiptToWithdraw);
            }

            if (lpReceipt.balanceOf(address(this)) > 0) {
                pool.remove_liquidity_one_coin(
                    lpReceipt.balanceOf(address(this)),
                    1,
                    0
                );
            }

            wantBal = IERC20(want).balanceOf(address(this));
        }

        if (wantBal > _amount) {
            wantBal = _amount;
        }

        if (tx.origin != owner() && !paused()) {
            uint256 withdrawalFeeBpsAmount = (wantBal * withdrawalFeeBps) /
                10_000;
            wantBal = wantBal - withdrawalFeeBpsAmount;
        }

        IERC20(want).safeTransfer(vault, wantBal);

        deposit();
    }

    function beforeDeposit() external payable {
        if (harvestOnDeposit) {
            require(msg.sender == vault, "!vault");
            _harvest();
        }
    }

    function harvest() external payable gasThrottle {
        _harvest();
    }

    function managerHarvest() external payable onlyManager {
        _harvest();
    }

    // compounds earnings and charges performance fee
    function _harvest() internal whenNotPaused {
        gauge.claim_rewards(); // claim LDO
        minter.mint(address(gauge)); // claim crv

        zapRewardsToNative(
            reward1.balanceOf(address(this)),
            reward2.balanceOf(address(this))
        );

        if (native.balanceOf(address(this)) > 0) chargeFees();

        if (native.balanceOf(address(this)) > 0)
            zapNativeToLpReceipt(native.balanceOf(address(this)));

        uint256 lpReceiptBalance = lpReceipt.balanceOf(address(this));
        if (lpReceiptBalance > 0) gauge.deposit(lpReceiptBalance);

        lastHarvest = block.timestamp;
    }

    // performance fees
    function chargeFees() internal {
        uint256 nativeBal = native.balanceOf(address(this));

        uint256 feeAmount = (nativeBal * feeOnProfitsBps) / 10_000;
        IERC20(native).safeTransfer(feeRecipient, feeAmount);
    }

    function zapRewardsToNative(
        uint256 reward1Amount,
        uint256 reward2Amount
    ) internal {
        if (reward1Amount > 0)
            reward1Pool.exchange(1, 0, reward1Amount, 0, false);

        if (reward2Amount > 0)
            reward2Pool.exchange(1, 0, reward2Amount, 0, false);
    }

    function zapWantToLpReceipt(uint256 _wantAmount) internal {
        uint256[2] memory amounts = [uint256(0), _wantAmount];
        pool.add_liquidity(amounts, 1);
    }

    function zapNativeToLpReceipt(uint256 _nativeAmount) internal {
        uint256[2] memory amounts = [_nativeAmount, 0];

        // wrap wnative to native
        IWNative(address(native)).withdraw(_nativeAmount);

        pool.add_liquidity{value: _nativeAmount}(amounts, 1);
    }

    function totalBalanceInWant() public view returns (uint256) {
        uint256 balance = IERC20(want).balanceOf(address(this));

        uint256 balanceInLpReceipt = totalBalanceInLpReceipt();
        if (balanceInLpReceipt != 0)
            balance += pool.calc_withdraw_one_coin(balanceInLpReceipt, 1);

        return balance;
    }

    // calculate the total underlaying LP Receipts held by the strat.
    function totalBalanceInLpReceipt() public view returns (uint256) {
        return balanceOfLpReceipt() + balanceOfGauge();
    }

    // it calculates how much 'want' this contract holds.
    function balanceOfLpReceipt() public view returns (uint256) {
        return lpReceipt.balanceOf(address(this));
    }

    // it calculates how much LP Receipts the strategy has working in the farm.
    function balanceOfGauge() public view returns (uint256) {
        return gauge.balanceOf(address(this));
    }

    function setHarvestOnDeposit(bool _harvestOnDeposit) external onlyManager {
        harvestOnDeposit = _harvestOnDeposit;

        if (harvestOnDeposit) {
            setWithdrawalFeeBps(0);
        } else {
            setWithdrawalFeeBps(10);
        }
    }

    function setShouldGasThrottle(
        bool _shouldGasThrottle
    ) external onlyManager {
        shouldGasThrottle = _shouldGasThrottle;
    }

    // called as part of strat migration. Sends all the available funds back to the vault.
    function retireStrat() external {
        require(msg.sender == vault, "!vault");

        gauge.withdraw(lpReceipt.balanceOf(address(this)));
        pool.remove_liquidity_one_coin(
            lpReceipt.balanceOf(address(this)),
            1,
            0
        );

        uint256 wantBal = IERC20(want).balanceOf(address(this));
        IERC20(want).transfer(vault, wantBal);
    }

    // pauses deposits and withdraws all funds from third party systems.
    function panic() public onlyManager {
        pause();
        gauge.withdraw(lpReceipt.balanceOf(address(this)));
    }

    function pause() public onlyManager {
        _pause();

        _removeAllowances();
    }

    function unpause() external onlyManager {
        _unpause();

        _giveAllowances();

        deposit();
    }

    function withdrawFeeBps() public view returns (uint256) {
        return paused() ? 0 : withdrawalFeeBps;
    }

    function _giveAllowances() internal {
        IERC20(want).safeApprove(address(pool), 0);
        IERC20(want).safeApprove(address(pool), type(uint).max);

        IERC20(native).safeApprove(address(pool), 0);
        IERC20(native).safeApprove(address(pool), type(uint).max);

        IERC20(reward1).safeApprove(address(reward1Pool), 0);
        IERC20(reward1).safeApprove(address(reward1Pool), type(uint).max);

        IERC20(reward2).safeApprove(address(reward2Pool), 0);
        IERC20(reward2).safeApprove(address(reward2Pool), type(uint).max);

        lpReceipt.safeApprove(address(gauge), 0);
        lpReceipt.safeApprove(address(gauge), type(uint).max);
    }

    function _removeAllowances() internal {
        IERC20(want).safeApprove(address(pool), 0);
        IERC20(native).safeApprove(address(pool), 0);
        IERC20(reward1).safeApprove(address(reward1Pool), 0);
        IERC20(reward2).safeApprove(address(reward2Pool), 0);
        lpReceipt.safeApprove(address(gauge), 0);
    }

    receive() external payable {}
}
