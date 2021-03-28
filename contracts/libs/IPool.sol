
// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

interface IPool {

    function deposit(uint256 _pid, uint256 _amount) external;

    function getReward() external;

    function withdraw(uint256 _pid, uint256 _amount) external;

    function withdraw(uint256 _amount) external;

    function withdrawAll() external;

    function claim() external;

    function emergencyWithdraw(uint256 _pid) external;

    function pendingAUTO(uint256 _pid, address _user) external view returns (uint256);

    function pendingBlzd(uint256 _pid, address _user) external view returns (uint256);

}