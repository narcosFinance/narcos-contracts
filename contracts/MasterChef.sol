// SPDX-License-Identifier: MIT

//narcos.finance

pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "./libs/IBEP20.sol";
import "./libs/SafeBEP20.sol";
import "./libs/IStrategy.sol";
import "./libs/ISChef.sol";
import "./libs/IDeflation.sol";
import "./libs/INFTs.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./NarcosToken.sol";

contract MasterChef is Ownable {
    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;

    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
    }

    struct PoolInfo {
        IBEP20 lpToken;
        uint256 allocPoint;
        uint256 lastRewardBlock;
        uint256 accTokenPerShare;
        uint16 depositFeeBP;
    }

    struct StrategInfo {
        IStrategy strategy;
        uint16 feeStra;
        uint256 idNFT;
        uint256 d_token;
        uint256 d_wbnb;
        uint256 d_cake;
        uint256 d_btcb;
        uint256 d_eth;
        uint256 amount;
    }    

    NarcosToken public token;
    INFTs public nft;
    address public devaddr;
    uint256 public tokenPerBlock;
    uint256 public constant BONUS_MULTIPLIER = 1;
    address public feeAddress;

    PoolInfo[] public poolInfo;
    StrategInfo[] public strategInfo;
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;
    uint256 public totalAllocPoint = 0;
    uint256 public startBlock;
    address public setup;
    bool public paused = true;
    mapping(address => bool) public tokens;
    ISChef public wbnbChef;
    ISChef public cakeChef;
    ISChef public btcbChef;
    ISChef public ethChef;
    bool public checkSetup;

    address public moderator;
    address[] public pathToken;
    mapping(address => address[]) public pathTokenStrategy;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event SetFeeAddress(address indexed user, address indexed _feeAddress);
    event SetDevAddress(address indexed user, address indexed _devaddr);
    event SetUpdateEmissionRate(uint256 indexed last_tokenPerBlock, uint256 indexed new_tokenPerBlock);
    event SetPaused(bool _status);

    constructor(
        NarcosToken _token,
        INFTs _nft,
        address _devaddr,
        address _feeAddress,
        uint256 _tokenPerBlock,
        uint256 _startBlock,
        ISChef _wbnbChef,
        ISChef _cakeChef,
        ISChef _btcbChef,
        ISChef _ethChef
    ) public {
        token = _token;
        nft = _nft;
        devaddr = _devaddr;
        feeAddress = _feeAddress;
        tokenPerBlock = _tokenPerBlock;
        startBlock = _startBlock;
        wbnbChef = _wbnbChef;
        cakeChef = _cakeChef;
        btcbChef = _btcbChef;
        ethChef = _ethChef;
        moderator = msg.sender;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    function add(uint256 _allocPoint, IBEP20 _lpToken, uint16 _depositFeeBP, bool _withUpdate, IStrategy _strategy, uint16 _feeStra, uint256 _idNFT, uint256 _d_token, uint256 _d_wbnb, uint256 _d_cake, uint256 _d_btcb, uint256 _d_eth) public onlyOwnerAndSetup {
        require(tokens[address(_lpToken)] == false, "Lp already exists");
        require(_depositFeeBP <= 10000, "add: invalid deposit fee basis points");
        require(_d_token.add(_d_wbnb).add(_d_cake).add(_d_btcb).add(_d_eth) == 100, "the sum must be equal to one hundred");
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(PoolInfo({
            lpToken: _lpToken,
            allocPoint: _allocPoint,
            lastRewardBlock: lastRewardBlock,
            accTokenPerShare: 0,
            depositFeeBP: _depositFeeBP
        }));
        strategInfo.push(StrategInfo({
            strategy: _strategy,
            feeStra: _feeStra,
            idNFT: _idNFT,
            d_token: _d_token,
            d_wbnb: _d_wbnb,
            d_cake: _d_cake,
            d_btcb: _d_btcb,
            d_eth: _d_eth,
            amount: 0
        }));
        wbnbChef.add(_allocPoint);
        cakeChef.add(_allocPoint);
        btcbChef.add(_allocPoint);
        ethChef.add(_allocPoint);
        checkSetup = true;
    }

    function set(uint256 _pid, uint256 _allocPoint, uint16 _depositFeeBP, bool _withUpdate, uint16 _feeStra, uint256 _d_token, uint256 _d_wbnb, uint256 _d_cake, uint256 _d_btcb, uint256 _d_eth) public onlyOwner {
        require(_depositFeeBP <= 10000, "set: invalid deposit fee basis points");
        require(_d_token.add(_d_wbnb).add(_d_cake).add(_d_btcb).add(_d_eth) == 100, "the sum must be equal to one hundred");
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        poolInfo[_pid].allocPoint = _allocPoint;
        poolInfo[_pid].depositFeeBP = _depositFeeBP;
        strategInfo[_pid].feeStra = _feeStra;
        strategInfo[_pid].d_token = _d_token;
        strategInfo[_pid].d_wbnb = _d_wbnb;
        strategInfo[_pid].d_cake = _d_cake;
        strategInfo[_pid].d_btcb = _d_btcb;
        strategInfo[_pid].d_eth = _d_eth;
        wbnbChef.set(_pid, _allocPoint);
        cakeChef.set(_pid, _allocPoint);
        btcbChef.add(_allocPoint);
        ethChef.add(_allocPoint);
    }

    function getMultiplier(uint256 _from, uint256 _to) public pure returns (uint256) {
        return _to.sub(_from).mul(BONUS_MULTIPLIER);
    }

    function pendingToken(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        StrategInfo storage stra = strategInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accTokenPerShare = pool.accTokenPerShare;
        uint256 lpSupply = stra.amount;
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            uint256 tokenReward = multiplier.mul(tokenPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
            accTokenPerShare = accTokenPerShare.add(tokenReward.mul(1e12).div(lpSupply));
        }
        uint256 pending = user.amount.mul(accTokenPerShare).div(1e12).sub(user.rewardDebt);
        pending = pending.mul(stra.d_token).div(100);
        return pending;
    }

    function pendingStrategy(uint256 _pid) external view returns (uint256) {
        StrategInfo storage stra = strategInfo[_pid];
        if(address(stra.strategy) != address(0)){
            return stra.strategy.pending();
        }
        return 0;
    }

    function pendingWBNB(uint256 _pid, address _user) external view returns (uint256) {
        return wbnbChef.pendingReward(_pid, _user);
    }

    function pendingCAKE(uint256 _pid, address _user) external view returns (uint256) {
        return cakeChef.pendingReward(_pid, _user);
    }

    function pendingBTCB(uint256 _pid, address _user) external view returns (uint256) {
        return btcbChef.pendingReward(_pid, _user);
    }

    function pendingETH(uint256 _pid, address _user) external view returns (uint256) {
        return ethChef.pendingReward(_pid, _user);
    }
    
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        StrategInfo storage stra = strategInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = stra.amount;
        if (lpSupply == 0 || pool.allocPoint == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 tokenReward = multiplier.mul(tokenPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
        token.mint(devaddr, tokenReward.div(10));
        token.mint(address(this), tokenReward);
        pool.accTokenPerShare = pool.accTokenPerShare.add(tokenReward.mul(1e12).div(lpSupply));
        pool.lastRewardBlock = block.number;
        IDeflation(address(token)).grillPool(0);
        IDeflation(address(token)).grillPool(1);
    }

    function _deposit(uint256 _pid, uint256 _amount, uint256 _perc, ISChef _token, uint256 _amountGlobal) internal {
        if(_perc > 0){
            if(_amount > 0){
                _amount = _amount.mul(_perc).div(100);
            }
            if(_amountGlobal > 0){
                _amountGlobal = _amountGlobal.mul(_perc).div(100);
            }
            _token.deposit(_pid, _amount, msg.sender, _amountGlobal);
        }
    }

    function deposit(uint256 _pid, uint256 _amount) public {
        require(paused == false, "!paused");
        PoolInfo storage pool = poolInfo[_pid];
        StrategInfo storage stra = strategInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if(address(stra.strategy) != address(0)){
            stra.strategy.deposit(0);
        }
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accTokenPerShare).div(1e12).sub(user.rewardDebt);
            pending = pending.mul(stra.d_token).div(100);
            if(pending > 0) {
                safeTokenTransfer(msg.sender, pending);
            }
        }
        uint256 depositFeeBuy = 0;
        uint256 depositFeeStra = 0;        
        if(_amount > 0) {
            if(stra.idNFT > 0){
                require(nft.checkNFT(msg.sender, stra.idNFT) == true, "No NTFs to deposit");
            }
            pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            if(pool.depositFeeBP > 0){
                depositFeeBuy = _amount.mul(pool.depositFeeBP).div(10000);
            }
            if(stra.feeStra > 0){
                depositFeeStra = _amount.mul(stra.feeStra).div(10000);
            }
            user.amount = user.amount.add(_amount).sub(depositFeeBuy).sub(depositFeeStra);
            stra.amount = stra.amount.add(_amount).sub(depositFeeBuy).sub(depositFeeStra);
            if(depositFeeBuy > 0){
                pool.lpToken.safeTransfer(feeAddress, depositFeeBuy);
            }
            if(address(stra.strategy) != address(0)){
                pool.lpToken.safeApprove(address(stra.strategy), 0);
                pool.lpToken.safeApprove(address(stra.strategy), _amount.sub(depositFeeBuy));
                stra.strategy.deposit(_amount.sub(depositFeeBuy));
            }
        }
        user.rewardDebt = user.amount.mul(pool.accTokenPerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
        _deposit(_pid, _amount.sub(depositFeeBuy).sub(depositFeeStra), stra.d_wbnb, wbnbChef, user.amount);
        _deposit(_pid, _amount.sub(depositFeeBuy).sub(depositFeeStra), stra.d_cake, cakeChef, user.amount);
        _deposit(_pid, _amount.sub(depositFeeBuy).sub(depositFeeStra), stra.d_btcb, btcbChef, user.amount);
        _deposit(_pid, _amount.sub(depositFeeBuy).sub(depositFeeStra), stra.d_eth, ethChef, user.amount);
    }

    function _withdraw(uint256 _pid, uint256 _amount, uint256 _perc, ISChef _token, uint256 _amountGlobal) internal {
        if(_perc > 0){
            if(_amount > 0){
                _amount = _amount.mul(_perc).div(100);
            }
            if(_amountGlobal > 0){
                _amountGlobal = _amountGlobal.mul(_perc).div(100);
            }
            _token.withdraw(_pid, _amount, msg.sender, _amountGlobal);
        }
    }

    function withdraw(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        StrategInfo storage stra = strategInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        if(address(stra.strategy) != address(0)){
            stra.strategy.withdraw(0);
        }        
        uint256 pending = user.amount.mul(pool.accTokenPerShare).div(1e12).sub(user.rewardDebt);
        pending = pending.mul(stra.d_token).div(100);
        if(pending > 0) {
            safeTokenTransfer(msg.sender, pending);
        }
        if(_amount > 0) {
            if(address(stra.strategy) != address(0)){
                stra.strategy.withdraw(_amount);
            }              
            user.amount = user.amount.sub(_amount);
            stra.amount = stra.amount.sub(_amount);
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accTokenPerShare).div(1e12);
        emit Withdraw(msg.sender, _pid, _amount);
        _withdraw(_pid, _amount, stra.d_wbnb, wbnbChef, user.amount);
        _withdraw(_pid, _amount, stra.d_cake, cakeChef, user.amount);
        _withdraw(_pid, _amount, stra.d_btcb, btcbChef, user.amount);
        _withdraw(_pid, _amount, stra.d_eth, ethChef, user.amount);
    }

    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        StrategInfo storage stra = strategInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        uint256 amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        if(address(stra.strategy) != address(0)){
            stra.strategy.emergencyWithdraw(amount);
        }
        stra.amount = stra.amount.sub(amount);        
        pool.lpToken.safeTransfer(address(msg.sender), amount);
        wbnbChef.emergencyWithdraw(_pid, msg.sender);
        cakeChef.emergencyWithdraw(_pid, msg.sender);
        btcbChef.emergencyWithdraw(_pid, msg.sender);
        ethChef.emergencyWithdraw(_pid, msg.sender);
        emit EmergencyWithdraw(msg.sender, _pid, amount);
    }

    function safeTokenTransfer(address _to, uint256 _amount) internal {
        uint256 tokenBal = token.balanceOf(address(this));
        if (_amount > tokenBal) {
            token.transfer(_to, tokenBal);
        } else {
            token.transfer(_to, _amount);
        }
    }

    function dev(address _devaddr) public {
        require(msg.sender == devaddr, "dev: wut?");
        devaddr = _devaddr;
        emit SetDevAddress(msg.sender, _devaddr);
    }

    function setFeeAddress(address _feeAddress) public{
        require(msg.sender == feeAddress, "setFeeAddress: FORBIDDEN");
        feeAddress = _feeAddress;
        emit SetFeeAddress(msg.sender, _feeAddress);
    }

    function updateEmissionRate(uint256 _tokenPerBlock) public onlyOwner {
        massUpdatePools();
        uint256 last_tokenPerBlock = tokenPerBlock;
        tokenPerBlock = _tokenPerBlock;
        emit SetUpdateEmissionRate(last_tokenPerBlock, _tokenPerBlock);
    }

    function updatePaused(bool _value) public onlyOwner {
        paused = _value;
        emit SetPaused(_value);
    }

    function addSetup(address _setup) external {
        require(setup == address(0));
        setup = _setup;
    }

    function changeSetup(address _setup) onlyOwner public {
        require(checkSetup == false, "!checkSetup");
        setup = _setup;
    }    

    function removeStrategy(uint256 _pid) external onlyOwner {
        StrategInfo storage stra = strategInfo[_pid];
        stra.strategy.emergencyWithdrawChef();
        stra.strategy = IStrategy(address(0));
    }

    modifier onlyOwnerAndSetup() {
        require(owner() == msg.sender || setup == msg.sender, "Ownable: caller is not the owner or setup");
        _;
    }    

    modifier onlyMod() {
        require(moderator == msg.sender, "Must be mod");
        _;
    }

    function changeMod(address _addr) public {
        require(msg.sender == moderator, "mod: wut?");
        moderator = _addr;
    }     

    function setPathTokenStrategy(address _token, address[] calldata _path) onlyMod external {
        pathTokenStrategy[_token] = _path;
    }

    function setPathToken(address[] calldata _path) onlyMod external {
        pathToken = _path;
    }    

    function getPathToken() public view returns(address[] memory) {
        uint256 _length =  pathToken.length;
        address[] memory _paths = new address[](_length);
        for (uint256 i = 0; i < _length; i++) {
            _paths[i] = pathToken[i];
        }
        return _paths;
    }

    function getPathTokenStrategy(address _token) public view returns(address[] memory) {
        uint256 _length =  pathTokenStrategy[_token].length;
        address[] memory _paths = new address[](_length);
        for (uint256 i = 0; i < _length; i++) {
            _paths[i] = pathTokenStrategy[_token][i];
        }
        return _paths;
    }    

}
