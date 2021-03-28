// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

interface IStrategy {

    function deposit(uint256 _amount) external;

    function withdraw(uint256 _amount) external;

    function emergencyWithdraw(uint256 _amount) external;

    function claim(address _user) external;

    function balanceToken() external view returns(uint256);

    function balanceWBNB() external view returns(uint256);

    function balanceBUSD() external view returns(uint256);

    function balanceTokenMain() external view returns(uint256);

    function balanceETH() external view returns(uint256);

    function balanceBTCB() external view returns(uint256);

    function balanceLP() external view returns(uint256);

    function pending() external view returns(uint256);

    function emergencyWithdrawChef() external;

}