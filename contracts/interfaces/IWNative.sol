// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IWNative {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 amount) external returns (bool);

    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);

    function deposit() external payable;

    function withdraw(uint256 wad) external;

    function decimals() external view returns (uint8);

    function name() external view returns (string memory);
}
