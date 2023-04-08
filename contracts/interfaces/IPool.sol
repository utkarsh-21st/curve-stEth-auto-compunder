// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IPool {
    function add_liquidity(
        uint256[2] memory amounts,
        uint256 min_mint_amount
    ) external payable;

    function remove_liquidity_one_coin(
        uint256 _token_amount,
        int128 i,
        uint256 _min_amount
    ) external returns (uint256);

    function exchange(
        uint256 i,
        uint256 j,
        uint256 dx,
        uint256 min_dy,
        bool use_eth
    ) external;

    function coins(uint256 i) external view returns (address);

    function lp_token() external view returns (address);

    function calc_withdraw_one_coin(
        uint256 _token_amount,
        int128 i
    ) external view returns (uint256);

    function calc_token_amount(
        uint256[2] memory amounts,
        bool is_deposit
    ) external view returns (uint256);
}
