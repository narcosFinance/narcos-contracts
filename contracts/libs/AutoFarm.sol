  
// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "./IBEP20.sol";
import "./SafeBEP20.sol";
import "./IPool.sol";
import "./ISChef.sol";
import "./IPancakeSwapRouter.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract AutoFarm is Ownable {

    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;

    IPancakeSwapRouter public router = IPancakeSwapRouter(0x05fF2B0DB69458A0750badebc4f9e13aDd608C7F);
    IPool public pool = IPool(0x0895196562C7868C5Be92459FaE7f877ED450452);
    IBEP20 public busd = IBEP20(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);
    IBEP20 public wbnb = IBEP20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IBEP20 public cake = IBEP20(0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82);
    IBEP20 public eth = IBEP20(0x2170Ed0880ac9A755fd29B2688956BD959F933F8);
    IBEP20 public btcb = IBEP20(0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c);      
    IBEP20 public token = IBEP20(0xa184088a740c695E156F91f5cC086a06bb78b827);

    uint256 public pid;
    IBEP20 public lp;
    address public chef;
    IBEP20 public tokenMain;
    address public dev;
    address public wbnbChef;
    address public cakeChef;
    address public ethChef;
    address public btcbChef;
    
    constructor(uint256 _pid, IBEP20 _lp, address _chef, IBEP20 _tokenMain, address _dev, address _wbnbChef, address _cakeChef, address _btcbChef, address _ethChef) public {
        pid = _pid;
        lp = _lp;
        chef = _chef;
        tokenMain = _tokenMain;
        dev = _dev;
        wbnbChef = _wbnbChef;
        cakeChef = _cakeChef;
        btcbChef = _btcbChef;
        ethChef = _ethChef;
    }

    function _BuyTokenAndBurn(uint256 _amount) internal {
        if(_amount > 0){
            busd.safeApprove(address(router), 0);
            busd.safeApprove(address(router), _amount);
            router.swapExactTokensForTokensSupportingFeeOnTransferTokens(_amount, uint256(0), ISChef(address(chef)).getPathToken(), address(this), now.add(1800));
            if(balanceTokenMain() > 0){
                tokenMain.safeTransfer(0x000000000000000000000000000000000000dEaD, balanceTokenMain());
            }
        }
    }

    function _BuyWBNBandSendSmartChef(uint256 _amount) internal {
        if(_amount > 0){
            busd.safeApprove(address(router), 0);
            busd.safeApprove(address(router), _amount);
            router.swapExactTokensForTokensSupportingFeeOnTransferTokens(_amount, uint256(0), ISChef(address(chef)).getPathTokenStrategy(address(wbnb)), address(this), now.add(1800));
            if(balanceWBNB() > 0){
                wbnb.safeTransfer(wbnbChef, balanceWBNB());
                ISChef(address(wbnbChef)).adjustBlockEnd();
            }
        }
    }

    function _BuyCAKEandSendSmartChef(uint256 _amount) internal {
        if(_amount > 0){
            busd.safeApprove(address(router), 0);
            busd.safeApprove(address(router), _amount);
            router.swapExactTokensForTokensSupportingFeeOnTransferTokens(_amount, uint256(0), ISChef(address(chef)).getPathTokenStrategy(address(cake)), address(this), now.add(1800));
            if(balanceCAKE() > 0){
                cake.safeTransfer(cakeChef, balanceCAKE());
                ISChef(address(cakeChef)).adjustBlockEnd();
            }
        }
    }    

    function _BuyBTCBandSendSmartChef(uint256 _amount) internal {
        if(_amount > 0){
            busd.safeApprove(address(router), 0);
            busd.safeApprove(address(router), _amount);
            router.swapExactTokensForTokensSupportingFeeOnTransferTokens(_amount, uint256(0), ISChef(address(chef)).getPathTokenStrategy(address(btcb)), address(this), now.add(1800));
            if(balanceBTCB() > 0){
                btcb.safeTransfer(btcbChef, balanceBTCB());
                ISChef(address(btcbChef)).adjustBlockEnd();
            }
        }
    }

    function _BuyETHandSendSmartChef(uint256 _amount) internal {
        if(_amount > 0){
            busd.safeApprove(address(router), 0);
            busd.safeApprove(address(router), _amount);
            router.swapExactTokensForTokensSupportingFeeOnTransferTokens(_amount, uint256(0), ISChef(address(chef)).getPathTokenStrategy(address(eth)), address(this), now.add(1800));
            if(balanceETH() > 0){
                eth.safeTransfer(ethChef, balanceETH());
                ISChef(address(ethChef)).adjustBlockEnd();
            }
        }
    }
        
    function _convertTokenToBUSD() internal {
        uint256 _amount = balanceTOKEN();
        if(_amount > 0){
            token.safeApprove(address(router), 0);
            token.safeApprove(address(router), _amount);
            router.swapExactTokensForTokensSupportingFeeOnTransferTokens(_amount, uint256(0), ISChef(address(chef)).getPathTokenStrategy(address(token)), address(this), now.add(1800));
            if(balanceBUSD() > 0){
                uint256 _balanceGeneral = balanceBUSD();
                uint256 _amountDev = _balanceGeneral.mul(10).div(100);
                uint256 _amountBuyTokenAndBurn = _balanceGeneral.mul(40).div(100);
                busd.safeTransfer(dev, _amountDev);
                _BuyTokenAndBurn(_amountBuyTokenAndBurn);
                _balanceGeneral = balanceBUSD();
                _BuyWBNBandSendSmartChef(_balanceGeneral.div(4));
                _BuyCAKEandSendSmartChef(_balanceGeneral.div(4));
                _BuyBTCBandSendSmartChef(_balanceGeneral.div(4));
                _BuyETHandSendSmartChef(balanceBUSD());
            }
        }
    }

    function _convertToken() internal {
        uint256 _amount = balanceTOKEN();
        if(_amount > 0){
            _convertTokenToBUSD();
        }
    }

    function deposit(uint256 _amount) external {
        require(chef == msg.sender, "!chef");
        if(_amount > 0){
            lp.safeTransferFrom(chef, address(this), _amount);
            lp.safeApprove(address(pool), _amount);
        }
        pool.deposit(pid, _amount);
        _convertToken();
    }

    function withdraw(uint256 _amount) external {
        require(chef == msg.sender, "!chef");
        pool.withdraw(pid, _amount);
        lp.safeTransfer(chef, balanceLP());
        _convertToken();
    }

    function emergencyWithdraw(uint256 _amount) external {
        require(chef == msg.sender, "!chef");
        pool.withdraw(pid, _amount);
        lp.safeTransfer(chef, balanceLP());
    }

    function emergencyWithdrawChef() external {
        require(chef == msg.sender, "!chef");
        pool.emergencyWithdraw(pid);
        lp.safeTransfer(chef, balanceLP());
        _convertToken();
    }

    function balanceBUSD() public view returns(uint256){
        return busd.balanceOf(address(this));
    }

    function balanceWBNB() public view returns(uint256){
        return wbnb.balanceOf(address(this));
    }        

    function balanceTokenMain() public view returns(uint256){
        return tokenMain.balanceOf(address(this));
    }   

    function balanceCAKE() public view returns(uint256){
        return cake.balanceOf(address(this));
    }     
    
    function balanceTOKEN() public view returns(uint256){
        return token.balanceOf(address(this));
    }     

    function balanceLP() public view returns(uint256){
        return lp.balanceOf(address(this));
    }

    function balanceETH() public view returns(uint256){
        return eth.balanceOf(address(this));
    }

    function balanceBTCB() public view returns(uint256){
        return btcb.balanceOf(address(this));
    }
    
    function pending() external view returns (uint256) {
        return pool.pendingAUTO(pid, address(this));
    }       
    
}