// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

interface ISChef {

    function rewardPerBlock() external view returns(uint256);

    function pendingReward(uint256 _pid, address _user) external view returns (uint256);

    function userInfo(uint256 _pid, address _user) external view returns (uint256, uint256);

    function poolInfo(uint256 _pid) external view returns (uint256, uint256, uint256, uint16, uint16);

    function deposit(uint256 _pid, uint256 _amount, address _userToken, uint256 _amountGlobal) external;

    function withdraw(uint256 _pid, uint256 _amount, address _userToken, uint256 _amountGlobal) external;

    function emergencyWithdraw(uint256 _pid, address _userToken) external;

    function add(uint256 _allocPoint) external;

    function set(uint256 _pid, uint256 _allocPoint) external;

    function adjustBlockEnd() external;

    function getPathToken() external view returns(address[] memory);
    
    function getPathTokenStrategy(address _token) external view returns(address[] memory);

    function getPathTokenStrategySell(address _token) external view returns(address[] memory);

}