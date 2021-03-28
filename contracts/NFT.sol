// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract NFTs is ERC721, Ownable {
    
    using SafeMath for uint256;
    IERC20 public token;    
    uint256 public lastId;
    address dead = 0x000000000000000000000000000000000000dEaD;

    struct PathStruct {
        bool isExist;
        uint256 id;
        uint256 price;
        string path;
    }
    mapping(uint => PathStruct) public paths;
    mapping(uint => address) public nftAddress;
    mapping(address => mapping(uint => uint)) public tokensUser;
    uint256 public lastIdPath;

    constructor(IERC20 _token) public ERC721("CAPOS NFTs", "CAPOS") {
        token = _token;
        _newNFT(0, "");
        lastId = 1;
    }

    function _newNFT(uint256 _price, string memory _path) internal {
        PathStruct memory Path_Struct;
        Path_Struct = PathStruct({
            isExist: true,
            id: lastIdPath,
            price: _price,
            path: _path
        });
        paths[lastIdPath] = Path_Struct;
        lastIdPath++;
    }

    function newNFT(uint256 _price, string memory _path) onlyOwner external {
        _newNFT(_price, _path);
    }
    
    function updatePrice(uint256 _price, uint256 _id) onlyOwner external {
        require(paths[_id].isExist == true, "!isExist");
        paths[_id].price = _price;
    }    

    function updatePriceAll(uint256 _price) onlyOwner external {
        for (uint i = 0; i < lastIdPath; i++) {
            paths[i].price = _price;
        }
    }  

    function buy(uint _id) external {
        require(_id > 0, "!id");
        require(paths[_id].isExist == true, "!isExist");
        require(token.transferFrom(msg.sender, address(this), paths[_id].price) == true, "You have not approved the deposit");
        _mint(msg.sender, lastId);
        _setTokenURI(lastId, paths[_id].path);
        token.transfer(dead, paths[_id].price);
        nftAddress[lastId] = msg.sender;
        tokensUser[msg.sender][_id] = lastId;
        lastId++;
    }

    function getTokens(address _user) public view returns (uint[] memory) {
        uint[] memory parentTokens = new uint[](lastIdPath);
        for (uint i = 0; i < lastIdPath; i++) {
            if(ownerOf(tokensUser[_user][i]) == _user){
                parentTokens[i] = i;
            }
        }
        return parentTokens;
    }

    function checkNFT(address _user, uint _id) public view returns (bool) {
        if(ownerOf(tokensUser[_user][_id]) == _user){
            return true;
        } else {
            return false;
        }
    }

}