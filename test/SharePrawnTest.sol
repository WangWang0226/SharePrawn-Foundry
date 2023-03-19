pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../src/SharePrawn.sol";
import { IUniswapV2Factory, IUniswapV2Pair, IUniswapV2Router01, IUniswapV2Router02 } from "../src/Interface.sol";

contract SharePrawnTest is Test {
    SharePrawn public sharePrawn;
    IUniswapV2Router02 public uniswapV2Router02;
    uint timestamp;
    address alice;
    address bob;
    address charlie;
    address david;

    uint private _decimals = 10**18;
    event log_balance_uint(string key, uint val);

    function setUp() public {
        // set timestamp
        timestamp = 16182521;
        vm.warp(timestamp);

        sharePrawn = new SharePrawn();

        uniswapV2Router02 = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        
        // owner (此測試合約)有十億 token
        emit log_balance_uint("balance:", sharePrawn.balanceOf(address(this)));

        // owner 給合約一億顆 token
        sharePrawn.transfer(address(sharePrawn), 100000000 * _decimals);
        assertEq(sharePrawn.balanceOf(address(sharePrawn)), 95477386934673366834170854);

        // [owner, alice, bob, charlie, david] = await ethers.getSigners();
        
        // 給合約一千萬顆 eth
        vm.deal(address(sharePrawn), 10000000 ether);
        assertEq(address(sharePrawn).balance, 10000000 ether);

        console2.log("start init liquidity");

        // 先添加流動性
        sharePrawn.initLiquidity();

        alice = vm.addr(1);
        bob = vm.addr(2);
        charlie = vm.addr(3);
        david = vm.addr(4);

        // owner 給 alice 10000 顆 token
        sharePrawn.transfer(address(alice), 10000 * _decimals);
        console2.log("Alice token balance", sharePrawn.balanceOf(address(alice)));

        // owner 給 bob 20000 顆 token
        sharePrawn.transfer(address(bob), 20000 * _decimals);
        console2.log("Bob token balance", sharePrawn.balanceOf(address(bob)));

        // owner 給 charlie 30000 顆 token
        sharePrawn.transfer(address(charlie), 30000 * _decimals);
        console2.log("Charlie token balance", sharePrawn.balanceOf(address(charlie)));

        // owner 給 david 40000 顆 token
        sharePrawn.transfer(address(david), 40000 * _decimals);
        console2.log("David token balance", sharePrawn.balanceOf(address(david)));

        // Alice, Bob 分別鎖倉 20 天與 30 天，Charlie 沒鎖倉
        vm.prank(address(alice));
        sharePrawn.stacking(20);

        vm.prank(address(bob));
        sharePrawn.stacking(30);
        
    }

    // 每次 Transfer 會徵收 5% 的稅，即時依照餘額比例分給所有持幣者
    function testTransfer() public {
        uint aliceBalance; uint bobBalance; uint charlieBalance;
        (aliceBalance, bobBalance, charlieBalance, ) = getAccountBalances();

        // owner 給 david 40000 顆 token
        sharePrawn.transfer(address(david), 40000 * _decimals);

        //  檢查每個地址獲得的分潤量
        uint aliceBalanceAfter; uint bobBalanceAfter; uint charlieBalanceAfter;
        (aliceBalanceAfter, bobBalanceAfter, charlieBalanceAfter, ) = getAccountBalances();

        uint aliceShare = (aliceBalanceAfter - aliceBalance) / 1000000000000;
        console2.log("Alice got share:", aliceShare);

        uint bobShare = (bobBalanceAfter - bobBalance) / 1000000000000;
        assertEq(bobShare, aliceShare * 2); // bob 持幣為 Alice 的兩倍，因此分潤也是兩倍

        uint charlieShare = (charlieBalanceAfter - charlieBalance) / 1000000000000;
        assertEq(charlieShare, aliceShare * 3); // charlie 持幣為 Alice 的三倍，因此分潤也是三倍

        // 沒有開放 r值讓外面取得，所以無法驗證得非常精確，但有驗證到使用者得到的分潤與持有的 token 數成正比

        // 另假設情境：rTotal = 800, tTotal = 1000, rate = 0.8
        // 有人發起交易金額 100 的交易：
        // tAmount = 100, tTransferAmount = 95, tFee = 5
        // rAmount = 80, rTransferAmount = 76, rFee = 4, 
        // 燃燒 rFee 後：
        // rTotal = 796, tTotal = 1000

        // 公式：balance = rAmount / (rTotal / tTotal)
        // 假設小明有 200 rToken, 小美有 100 rToken
        // 原本：小明餘額t = 200/ 0.8 = 250, 小美餘額t = 100 / 0.8 = 125
        // 現在：小明餘額t = 200/ 0.796 = 251.256, 小美餘額t = 100 / 0.796 = 125.628
        // 驗算：(手續費t:5) * (小明佔比:200/796) = 1.256; (手續費t:5) * (小美佔比:100/796) = 0.628，證明合約中的公式正確。

    }

    // 每次在 Uniswap 上賣出會徵收 10% 稅，5% 向 Uniswap 添加流動性，另外 5% 分給鎖倉玩家
    function testSellingOnUniswap() public {
        uint aliceBalance; uint bobBalance; uint charlieBalance; uint contractBalance;
        (aliceBalance, bobBalance, charlieBalance, contractBalance) = getAccountBalances();

        uint swapAmount = 1000 * _decimals;
        address[] memory path = new address[](2);
        path[0] = address(sharePrawn);
        path[1] = uniswapV2Router02.WETH();

        // David 賣掉 1000 顆 token
        vm.startPrank(address(david));
        sharePrawn.approve(address(uniswapV2Router02), swapAmount);
        uniswapV2Router02.swapExactTokensForETHSupportingFeeOnTransferTokens(
            swapAmount,
            0, // accept any amount of ETH
            path,
            address(david),
            timestamp + 300
        );
        vm.stopPrank();


        uint aliceBalanceAfter; uint bobBalanceAfter; uint charlieBalanceAfter; uint contractBalanceAfter;
        (aliceBalanceAfter, bobBalanceAfter, charlieBalanceAfter, contractBalanceAfter) = getAccountBalances();  

        // 檢查每次在 Uniswap 賣出後，合約有沒有收集到 1000*0.05 = 50 (該交易額的 5%)，之後要用於添加流動性。
        assertEq(contractBalanceAfter - contractBalance, 50 * _decimals);

        // 檢查每次在 Uniswap 賣出後，鎖倉玩家獲得的分潤，是不是與他們鎖倉時長成正比。
        // Alice 鎖倉 20 天，Bob 鎖倉 30 天 -> Alice 的份額是 2/5，Bob 的份額是 3/5，Charlie 沒鎖倉不會獲得分潤
        assertEq(aliceBalanceAfter - aliceBalance, 50 * _decimals * 2 / 5);
        assertEq(bobBalanceAfter - bobBalance, 50 * _decimals * 3 / 5);
        assertEq(charlieBalanceAfter, charlieBalance);
       
    }

    // 鎖倉測試
    function testLockStacking() public {

        // alice 與 bob 鎖倉後不能進行轉帳
        vm.prank(address(alice));
        vm.expectRevert(bytes('not allowed to transfer until unlock stacking date'));
        bool isSuccess = sharePrawn.transfer(address(charlie), 100000);
        assertEq(isSuccess, false);

        vm.prank(address(bob));
        vm.expectRevert(bytes('not allowed to transfer until unlock stacking date'));
        isSuccess = sharePrawn.transfer(address(charlie), 100000);
        assertEq(isSuccess, false);

        //  過了 25 天
        vm.warp(timestamp + 25 * 24 * 60 * 60);
        
        // alice 已過鎖倉期限可以轉帳， 而 bob 還不能進行轉帳
        vm.prank(address(alice));
        isSuccess = sharePrawn.transfer(address(charlie), 100000);
        assertTrue(isSuccess);

        vm.prank(address(bob));
        vm.expectRevert(bytes('not allowed to transfer until unlock stacking date'));
        isSuccess = sharePrawn.transfer(address(charlie), 100000);
        assertEq(isSuccess, false);

    }

    function getAccountBalances() private view returns (uint aliceBalance, uint bobBalance, uint charlieBalance, uint contractBalance) {
        aliceBalance = sharePrawn.balanceOf(address(alice));
        bobBalance = sharePrawn.balanceOf(address(bob));
        charlieBalance = sharePrawn.balanceOf(address(charlie));
        contractBalance = sharePrawn.balanceOf(address(sharePrawn));
    }
}