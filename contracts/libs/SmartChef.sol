// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import './IBEP20.sol';
import './SafeBEP20.sol';
import "@openzeppelin/contracts/access/Ownable.sol";


contract SmartChef is Ownable {
    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;

    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
    }

    struct PoolInfo {
        uint256 allocPoint;
        uint256 lastRewardBlock;
        uint256 accRewardPerShare;
        uint256 amount;
    }

    IBEP20 public syrup;
    IBEP20 public rewardToken;

    uint256 public rewardPerBlock;

    PoolInfo[] public poolInfo;
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;
    uint256 private totalAllocPoint = 0;
    uint256 public startBlock;
    uint256 public bonusEndBlock;

    address public chef;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 amount);
    event SetUpdateEmissionRate(uint256 indexed tokenPerBlock, uint256 indexed _tokenPerBlock);

    constructor(
        IBEP20 _rewardToken,
        uint256 _rewardPerBlock,
        uint256 _startBlock,
        uint256 _bonusEndBlock
    ) public {
        rewardToken = _rewardToken;
        rewardPerBlock = _rewardPerBlock;
        startBlock = _startBlock;
        bonusEndBlock = _bonusEndBlock;
    }

    function addChef(address _chef) public onlyOwner {
        require(chef == address(0), "!addChef");
        chef = _chef;
    }

    function add(uint256 _allocPoint) public {
        require(msg.sender == chef, "!chef");
        poolInfo.push(PoolInfo({
            allocPoint: _allocPoint,
            lastRewardBlock: 0,
            accRewardPerShare: 0,
            amount: 0
        }));
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        massUpdatePools();
    }

    function set(uint256 _pid, uint256 _allocPoint) public {
        require(msg.sender == chef, "!chef");
        poolInfo[_pid].allocPoint = _allocPoint;
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        massUpdatePools();
    }

    function stopReward() public onlyOwner {
        bonusEndBlock = block.number;
    }

    function adjustBlockEnd() public {
        uint256 totalLeft = rewardToken.balanceOf(address(this));
        bonusEndBlock = block.number + totalLeft.div(rewardPerBlock);
    }

    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
        if (_to <= bonusEndBlock) {
            return _to.sub(_from);
        } else if (_from >= bonusEndBlock) {
            return 0;
        } else {
            return bonusEndBlock.sub(_from);
        }
    }

    function pendingReward(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accRewardPerShare = pool.accRewardPerShare;
        uint256 lpSupply = pool.amount;
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            uint256 cakeReward = multiplier.mul(rewardPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
            accRewardPerShare = accRewardPerShare.add(cakeReward.mul(1e18).div(lpSupply));
        }
        return user.amount.mul(accRewardPerShare).div(1e18).sub(user.rewardDebt);
    }

    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.amount;
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 cakeReward = multiplier.mul(rewardPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
        pool.accRewardPerShare = pool.accRewardPerShare.add(cakeReward.mul(1e18).div(lpSupply));
        pool.lastRewardBlock = block.number;
    }

    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    function deposit(uint256 _pid, uint256 _amount, address _userToken, uint256 _amountGlobal) public {
        require(msg.sender == chef, "!chef");
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_userToken];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accRewardPerShare).div(1e18).sub(user.rewardDebt);
            if(pending > 0) {
                user.rewardDebt = user.amount.mul(pool.accRewardPerShare).div(1e18);
                rewardToken.safeTransfer(address(_userToken), pending);
            }
        }
        if(_amount > 0) {
            pool.amount = pool.amount.add(_amount);
        }
        user.amount = _amountGlobal;
        user.rewardDebt = user.amount.mul(pool.accRewardPerShare).div(1e18);
        emit Deposit(_userToken, _amount);
    }

    function withdraw(uint256 _pid, uint256 _amount, address _userToken, uint256 _amountGlobal) public {
        require(msg.sender == chef, "!chef");
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_userToken];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accRewardPerShare).div(1e18).sub(user.rewardDebt);
        if(pending > 0) {
            rewardToken.safeTransfer(address(_userToken), pending);
        }
        if(_amount > 0) {
            pool.amount = pool.amount.sub(_amount);
        }
        user.amount = _amountGlobal;
        user.rewardDebt = user.amount.mul(pool.accRewardPerShare).div(1e18);
        emit Withdraw(_userToken, _amount);
    }

    function emergencyWithdraw(uint256 _pid, address _userToken) public {
        require(msg.sender == chef, "!chef");
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_userToken];
        pool.amount = pool.amount.sub(user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
        emit EmergencyWithdraw(_userToken, user.amount);
    }

    function emergencyRewardWithdraw(uint256 _amount) public onlyOwner {
        require(_amount <= rewardToken.balanceOf(address(this)), 'not enough token');
        rewardToken.safeTransfer(address(msg.sender), _amount);
    }

    function updateEmissionRate(uint256 _tokenPerBlock) public onlyOwner {
        massUpdatePools();
        uint256 last_tokenPerBlock = rewardPerBlock;
        rewardPerBlock = _tokenPerBlock;
        adjustBlockEnd();
        emit SetUpdateEmissionRate(last_tokenPerBlock, _tokenPerBlock);
    }

    function balance() public view returns(uint256){
        return rewardToken.balanceOf(address(this));
    }

}