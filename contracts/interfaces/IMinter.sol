// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IMinter {
    function mint(address gauge_addr) external;
}
