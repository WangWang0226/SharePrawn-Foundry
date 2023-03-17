// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { Ownable } from "openzeppelin-contracts/contracts/access/Ownable.sol";
import { Address } from "openzeppelin-contracts/contracts/utils/Address.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { Context } from "openzeppelin-contracts/contracts/utils/Context.sol";
import { IUniswapV2Factory, IUniswapV2Pair, IUniswapV2Router01, IUniswapV2Router02 } from "./Interface.sol";

contract SharePrawn is Context, IERC20, Ownable {
    using Address for address;

    uint private _decimals = 10**18;
    /**
     * tTotal: total amounts of tokens (cake)
     * rTotal: total amounts of reflection (plates)
     */
    uint256 private constant MAX = ~uint256(0);  //2**256-1
    // _tTotal = 十億
    uint256 private _tTotal = 1000000000 * _decimals;
    uint256 private _rTotal = (MAX - (MAX % _tTotal));
    
    uint256 private minAmountForAddLiquidity = 500 * _decimals;
    
    // tax fee for transfering token is 5%
    uint256 public _taxFee = 5;
    
    // tax fee for selling token is 10%
    uint256 public _sellingTokenFee = 10;

    // fee type
    enum FeeType {
        StackingFee,
        LiquidityFee
    }
    

    /** 
     * _rOwned: the amounts of reflection which the address has.
     */
    mapping (address => uint256) private _rOwned;

    mapping (address => uint256) private _stackingPeriodOf;
    mapping (address => bool) private _isStackingAccount;
    mapping (address => uint256) private _stackingUnlockTimeOf;
    address[] private _stackingAccounts;
    uint totalStackingSum; // 所有人總鎖倉時間總和
    uint totalStackingTFee; // 存在合約上的總鎖倉手續費
    uint totalLiquidityTFee; // 存在合約上的總流動性手續費

    IUniswapV2Router02 public immutable uniswapV2Router;
    address public immutable uniswapV2Pair;

    mapping (address => mapping (address => uint256)) private _allowances;

    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );


    bool isInSwapAndLiquify;

    modifier lockTheSwap {
        isInSwapAndLiquify = true;
        _;
        isInSwapAndLiquify = false;
    }

    constructor () {
        // transfer all balance to owner
        _rOwned[_msgSender()] = _rTotal;
        
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());

        uniswapV2Router = _uniswapV2Router;
                
        emit Transfer(address(0), _msgSender(), _tTotal);
    }

    /**
     * ------------ IERC20 function implementation ------------
     */
    function balanceOf(address account) public view override returns (uint256) {
        return convertReflectionToToken(_rOwned[account]);
    }

    function totalSupply() external view override returns (uint256) {
        return _tTotal;
    }

    function transfer(address recipient, uint256 amount) external override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    

    /**
     * ------------ IERC20 function implementation ------------
     */

    /**
     * ------------ core business logic ------------
     */

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        uint balanceFrom = balanceOf(from);
        require(balanceFrom >= amount, "ERC20: balance not enough");
        if(_isStackingAccount[from]) {
            //check current time is over the unlock stacking date or not
            require(block.timestamp >= _stackingUnlockTimeOf[from], "not allowed to transfer until unlock stacking date");
            // 動用餘額的時候才會將該帳號從鎖倉玩家名單中剔除
            resetStacking(from);
        }

        /** 每次在 Uniswap 上賣出會徵收 10% 的稅，其中 5% 會用來向 Uniswap 上的池子添加流動性，另外 5% 會分給代幣鎖倉的人
         * 判斷是不是賣出行為：在 uniswap 上 swap token 時，uniswapV2Router 會呼叫我們的 transfer，
         * 可以用 to == uniswapV2Router 判斷他是 1.賣出 token 或 2.添加流動性兩種行為。
         * 為了區分這兩種行為，再多設一個條件 from != address(this)，因為如果是添加流動性，from 一定是合約本身。
         */
        if(from != address(this) && to == uniswapV2Pair) {
            uint rFee = _tokenTransfer(from,to,amount, true);
            uint tFee = convertReflectionToToken(rFee);
            uint feeForLiquify = tFee / 2;
            uint feeForStackingUser = tFee - feeForLiquify;

            // 每次有人賣出代幣時，把 LiquidityFee 收集到合約上
            _collectFee(feeForLiquify, FeeType.LiquidityFee);

            // 每次有人賣出代幣時，先把 stackingFee 收集到合約上
            _collectFee(feeForStackingUser, FeeType.StackingFee);

            
            // 5% 會用來向 Uniswap 上的池子添加流動性
            // 為了避免有些小額交易金額的 5% 可能少到連 gas fee 都不夠，所以不會每筆交易都直接將稅加入流動池
            // 設定若合約已經收集超過最低限制的 token 數量，才會將這些 fee 加入流動池
            bool isAddLiquidityEnable = totalLiquidityTFee >= minAmountForAddLiquidity;
            if (!isInSwapAndLiquify && from != uniswapV2Pair && isAddLiquidityEnable) {
                swapAndLiquify(totalLiquidityTFee);
            }

            // 5% 會分給代幣鎖倉玩家
            // 缺點：若玩家人數很多，會變成跑一個很大的迴圈，可能導致 gas fee 極高，超過單筆交易上限
            for (uint256 i = 0; i < _stackingAccounts.length; i++) {
                transferShare(_stackingAccounts[i]);
            }
            
        }
        // 正常 Transfer 時會徵收 5% 的稅，並依照餘額比例分給所有持幣者
        else {
            uint rFee = _tokenTransfer(from,to,amount, false);
            _burnReflection(rFee);
        }
    }

    function swapAndLiquify(uint256 amount) private lockTheSwap {
        uint256 half = amount / 2;
        uint256 otherHalf = amount - half;

        uint256 initialBalance = address(this).balance;

        swapTokensForEth(half); 

        // the ETH did we just swap into
        uint256 EthAmount = address(this).balance - initialBalance;

        // add liquidity to uniswap
        addLiquidity(otherHalf, EthAmount);
        
        emit SwapAndLiquify(half, EthAmount, otherHalf);
    }

    function swapTokensForEth(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // add the liquidity
        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            owner(),
            block.timestamp
        );
    }

    function _tokenTransfer(address sender, address recipient, uint256 amount, bool isSellingToken) private returns (uint){
        (uint256 rAmount, uint256 rActualTransferAmount, uint256 rFee, uint256 tTransferAmount) = _getValues(amount, isSellingToken);
        _rOwned[sender] = _rOwned[sender] - rAmount;
        _rOwned[recipient] = _rOwned[recipient] + rActualTransferAmount;
        emit Transfer(sender, recipient, tTransferAmount); 
        return rFee;
    }

    /**
     * @param n is how many days the user lock stacking
     */ 
    function stacking(uint n) public {
        _stackingAccounts.push(_msgSender());
		_stackingPeriodOf[_msgSender()] = n;
		_isStackingAccount[_msgSender()] = true;
		totalStackingSum = totalStackingSum + n;
		_stackingUnlockTimeOf[_msgSender()] = block.timestamp + n * 24 * 60 * 60;
    }

    function resetStacking(address account) private {
        for (uint256 i = 0; i < _stackingAccounts.length; i++) {
            if (_stackingAccounts[i] == account) {
                delete _stackingAccounts[i];
            }
        }

		_stackingPeriodOf[account] = 0;
		_isStackingAccount[account] = false;
		totalStackingSum = totalStackingSum - _stackingPeriodOf[account];
		_stackingUnlockTimeOf[account] = 0;
    }

    function transferShare(address account) private {
        uint rShare = getStackingShare(account);
		_rOwned[address(this)] = _rOwned[address(this)] - rShare;
        _rOwned[account] = _rOwned[account] + rShare;
    }


    /**
     * ------------ core business logic ------------
     */


    /**
     * ------------ Other logic ------------
     */

    function _burnReflection(uint256 rFee) private {
        _rTotal = _rTotal - rFee;
    }

    function _collectFee(uint256 tFee, FeeType feeType) private {
        if(feeType == FeeType.LiquidityFee) {
            totalLiquidityTFee = totalLiquidityTFee + tFee;
        }
        else if(feeType == FeeType.StackingFee) {
            totalStackingTFee = totalStackingTFee + tFee;
        }
        uint256 currentRate =  _getRate();
        uint256 rFee = tFee * currentRate;
        _rOwned[address(this)] = _rOwned[address(this)] + rFee;
    }

    
    function _getValues(uint256 tAmount, bool isSellingToken) private view returns (uint256, uint256, uint256, uint256) {
        (uint256 tTransferAmount, uint256 tFee) = _getTValues(tAmount, isSellingToken);
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = _getRValues(tAmount, tFee, _getRate());
        return (rAmount, rTransferAmount, rFee, tTransferAmount);
    }

    function _getTValues(uint256 tAmount,  bool isSellingToken) private view returns (uint256, uint256) {
        uint256 tFee = calculateTaxFee(tAmount, isSellingToken);
        uint256 tTransferAmount = tAmount - tFee;
        return (tTransferAmount, tFee);
    }

    function _getRValues(uint256 tAmount, uint256 tFee, uint256 currentRate) private pure returns (uint256, uint256, uint256) {
        uint256 rAmount = tAmount * currentRate;
        uint256 rFee = tFee * currentRate;
        uint256 rTransferAmount = rAmount - rFee;
        return (rAmount, rTransferAmount, rFee);
    }

    function _getRate() private view returns(uint256) {   
        return _rTotal / _tTotal;
    }

    function calculateTaxFee(uint256 _amount, bool isSellingToken) private view returns (uint256) {
        if(isSellingToken) {
            return _amount * _sellingTokenFee / 10**2;
        }
        else {
            return _amount * _taxFee / 10**2;
        }    
    }

    function convertReflectionToToken(uint rAmount) public view returns (uint256) {
        require(rAmount <= _rTotal, "Amount must be less than total reflections");
        uint256 currentRate =  _getRate();
        // convert reflection to tokens: rAmount * tSupply / rSupply
        return rAmount / currentRate;
    }

    function convertTokenToReflection(uint tAmount) public view returns (uint256) {
        require(tAmount <= _tTotal, "Amount must be less than total token");
        uint256 currentRate =  _getRate();
        // convert reflection to tokens: rAmount * tSupply / rSupply
        return tAmount * currentRate;
    }
    
    // to recieve ETH from uniswapV2Router when swaping
    receive() external payable {}

    //先乘後除可以用 fullMath，但該 library 要求 solidity >=0.4.0 <0.8.0 ，低於我們現有的版本。
    function getStackingShare(address account) public view returns (uint256){
		//依照該 user 鎖倉時長，算出份額
		uint256 currentRate =  _getRate();
        uint256 totalStackingRFee = totalStackingTFee * currentRate;
		return totalStackingRFee * _stackingPeriodOf[account] / totalStackingSum;
    }

    function initLiquidity() public onlyOwner {
        uint tokenBalance = balanceOf(address(this));
        uint ethBalance = address(this).balance;
        addLiquidity(tokenBalance, ethBalance);
    }

}