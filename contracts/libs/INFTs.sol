// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

interface INFTs {

    function checkNFT(address _user, uint _id) external view returns (bool);

}