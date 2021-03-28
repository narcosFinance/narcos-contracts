// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

interface IDeflation {

    function grillPool(uint _type) external;

    function getGrillAmount(uint _type) external view returns (uint256);

}