// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IGauge {
    function deposit(uint256 _value) external;

    function balanceOf(
        address _address
    ) external view returns (uint256 _balance);

    function claim_rewards() external;

    function withdraw(uint256 _value) external;
}
