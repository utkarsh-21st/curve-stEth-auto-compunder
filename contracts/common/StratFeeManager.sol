// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract StratFeeManager is Ownable, Pausable {
    // common addresses for the strategy
    address public vault;
    address public feeRecipient;

    uint256 public constant WITHDRAWAL_FEE_CAP = 50;
    uint256 public withdrawalFeeBps = 10;
    uint256 public feeOnProfitsBps = 400;

    event SetWithdrawalFeeBps(uint256 withdrawalFeeBps);
    event SetVault(address vault);
    event SetFeeRecipient(address feeRecipient);

    constructor(address _feeRecipient) {
        feeRecipient = _feeRecipient;
    }

    // checks that caller is either owner or keeper.
    modifier onlyManager() {
        require(msg.sender == owner());
        _;
    }

    // adjust withdrawal fee
    function setWithdrawalFeeBps(uint256 _fee) public onlyManager {
        require(_fee <= WITHDRAWAL_FEE_CAP, "!cap");
        withdrawalFeeBps = _fee;
        emit SetWithdrawalFeeBps(_fee);
    }

    // set new vault (only for strategy upgrades)
    function setVault(address _vault) external onlyOwner {
        vault = _vault;
        emit SetVault(_vault);
    }

    // set new fee address to receive fees
    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        feeRecipient = _feeRecipient;
        emit SetFeeRecipient(_feeRecipient);
    }
}
