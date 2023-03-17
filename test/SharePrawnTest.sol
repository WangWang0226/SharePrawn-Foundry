pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../src/SharePrawn.sol";

contract SharePrawnTest is Test {
    SharePrawn public sharePrawn;

    function setUp() public {
        sharePrawn = new SharePrawn();

        // [owner, alice, bob, charlie, david] = await ethers.getSigners();

        // const factory = await ethers.getContractFactory("SharePrawn", owner);
        // sharePrawn = await factory.deploy();
        // await sharePrawn.deployed();

        // uniswapV2Router = await ethers.getContractAt(uniswapV2RouterABI, '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D');

        // // owner 有十億 token
        // console.log("owner token balance", ethers.utils.formatUnits(await sharePrawn.balanceOf(owner.address), 18));

        // // owner 給合約一億顆 token
        // const initTokenAmount = ethers.utils.parseEther("100000000");
        // await sharePrawn.connect(owner).transfer(sharePrawn.address, initTokenAmount);
        // // expect(await sharePrawn.balanceOf(sharePrawn.address)).to.eq(initTokenAmount); //扣掉手續費剩 95477386934673366834170854
        
        // // owner 給合約一千萬顆 eth
        // const initEtherAmount = ethers.utils.parseEther("1000") 
        // await owner.sendTransaction({
        //     to: sharePrawn.address,
        //     value: initEtherAmount
        // })
        
        // expect(await ethers.provider.getBalance(sharePrawn.address)).to.eq(initEtherAmount) 

        // console.log("start init liquidity");

        // // 先添加流動性
        // await sharePrawn.connect(owner).initLiquidity();

        // // owner 給 alice 10000 顆 token
        // await sharePrawn.connect(owner).transfer(alice.address, ethers.utils.parseEther("10000"));
        // console.log("Alice token balance", ethers.utils.formatUnits(await sharePrawn.balanceOf(alice.address), 18));

        // // owner 給 bob 20000 顆 token
        // await sharePrawn.connect(owner).transfer(bob.address, ethers.utils.parseEther("20000"));
        // console.log("Bob token balance", ethers.utils.formatUnits(await sharePrawn.balanceOf(bob.address), 18));

        // // owner 給 charlie 30000 顆 token
        // await sharePrawn.connect(owner).transfer(charlie.address, ethers.utils.parseEther("30000"));
        // console.log("Charlie token balance", ethers.utils.formatUnits(await sharePrawn.balanceOf(charlie.address), 18));

        // // owner 給 david 40000 顆 token
        // await sharePrawn.connect(owner).transfer(david.address, ethers.utils.parseEther("40000"));
        // console.log("David token balance", ethers.utils.formatUnits(await sharePrawn.balanceOf(david.address), 18));

        // // Alice, Bob 分別鎖倉 20 天與 30 天，Charlie 沒鎖倉
        // await sharePrawn.connect(alice).stacking(20);
        // await sharePrawn.connect(bob).stacking(30);
        
    }

    function testTransfer() public {

    }

    // it("每次 Transfer 會徵收 5% 的稅，即時依照餘額比例分給所有持幣者", async function () {

    //     let [aliceBalance, bobBalance, charlieBalance] = await getTokenBalance(alice.address, bob.address, charlie.address);

    //     // 發起交易
    //     // owner 給 david 40000 顆 token
    //     await sharePrawn.connect(owner).transfer(david.address, ethers.utils.parseEther("40000"));
    //     console.log("David token balance", ethers.utils.formatUnits(await sharePrawn.balanceOf(david.address), 18));

    //     // 檢查每個地址獲得的分潤量
    //     let [aliceBalanceAfter, bobBalanceAfter, charlieBalanceAfter] = await getTokenBalance(alice.address, bob.address, charlie.address);

    //     let aliceShare = Math.round((aliceBalanceAfter - aliceBalance)*100000) / 100000
    //     console.log("Alice got share:", aliceShare); //0.019

    //     let bobShare = Math.round((bobBalanceAfter - bobBalance)*100000) / 100000
    //     console.log("Bob got share", bobShare);
    //     expect(bobShare).to.eq(0.038); // bob 持幣為 Alice 的兩倍，因此分潤也是兩倍

    //     let charlieShare = Math.round((charlieBalanceAfter - charlieBalance)*100000) / 100000
    //     console.log("Charlie got share", charlieShare);
    //     expect(charlieShare).to.eq(0.057); // charlie 持幣為 Alice 的三倍，因此分潤也是三倍

    //     // 沒有開放 r值讓外面取得，所以無法驗證得非常精確，但有驗證到使用者得到的分潤與持有的 token 數成正比

    //     // 另假設情境：rTotal = 800, tTotal = 1000, rate = 0.8
    //     // 有人發起交易金額 100 的交易：
    //     // tAmount = 100, tTransferAmount = 95, tFee = 5
    //     // rAmount = 80, rTransferAmount = 76, rFee = 4, 
    //     // 燃燒 rFee 後：
    //     // rTotal = 796, tTotal = 1000

    //     // 公式：balance = rAmount / (rTotal / tTotal)
    //     // 假設小明有 200 rToken, 小美有 100 rToken
    //     // 原本：小明餘額t = 200/ 0.8 = 250, 小美餘額t = 100 / 0.8 = 125
    //     // 現在：小明餘額t = 200/ 0.796 = 251.256, 小美餘額t = 100 / 0.796 = 125.628
    //     // 驗算：(手續費t:5) * (小明佔比:200/796) = 1.256; (手續費t:5) * (小美佔比:100/796) = 0.628，證明合約中的公式正確。

    // });

    function testSellingOnUniswap() public {

    }

    // it("每次在 Uniswap 上賣出會徵收 10% 稅，5% 向 Uniswap 添加流動性，另外 5% 分給鎖倉玩家", async function () {

    //     let [aliceBalance, bobBalance, charlieBalance] = await getTokenBalance(alice.address, bob.address, charlie.address);
    //     let contractBalanceBefore = ethers.utils.formatUnits(await sharePrawn.balanceOf(sharePrawn.address));

    //     // getting timestamp
    //     let block = await ethers.provider.getBlock(16182521);
    //     let timestamp = block.timestamp;        
    //     let ethAddress = await uniswapV2Router.WETH();
    //     let swapAmount = ethers.utils.parseEther("1000"); 

    //     await sharePrawn.connect(david).approve(uniswapV2Router.address, swapAmount);
    //     // David 賣掉 1000 顆 token
    //     await uniswapV2Router.connect(david).swapExactTokensForETHSupportingFeeOnTransferTokens(
    //         swapAmount,
    //         0, // accept any amount of ETH
    //         [sharePrawn.address, ethAddress],
    //         david.address,
    //         timestamp + 300
    //     );

    //     // 檢查每次在 Uniswap 賣出後，合約有沒有收集到 1000*0.05 = 50 (該交易額的 5%)，之後要用於添加流動性。
    //     let contractBalanceAfter = ethers.utils.formatUnits(await sharePrawn.balanceOf(sharePrawn.address));
    //     expect(contractBalanceAfter - contractBalanceBefore).to.eq(50);

    //     // 檢查每次在 Uniswap 賣出後，鎖倉玩家獲得的分潤，是不是與他們鎖倉時長成正比。
    //     let [aliceBalanceAfter, bobBalanceAfter, charlieBalanceAfter] = await getTokenBalance(alice.address, bob.address, charlie.address);
        
    //     // Alice 鎖倉 20 天，Bob 鎖倉 30 天 -> Alice 的份額是 2/5，Bob 的份額是 3/5，Charlie 沒鎖倉不會獲得分潤
    //     expect(aliceBalanceAfter - aliceBalance).to.eq(50 * 2/5);
    //     expect(bobBalanceAfter - bobBalance).to.eq(50 * 3/5);
    //     expect(charlieBalanceAfter - charlieBalance).to.eq(0);

    // });

    function testLockStacking() public {

    }

    // it("鎖倉測試", async function () {

    //     // alice 與 bob 鎖倉後不能進行轉帳
    //     await expect(sharePrawn.connect(alice).transfer(charlie.address, 100000000)).to.be.revertedWith(
    //         "not allowed to transfer until unlock stacking date",
    //     )
    //     await expect(sharePrawn.connect(bob).transfer(charlie.address, 100000000)).to.be.revertedWith(
    //         "not allowed to transfer until unlock stacking date",
    //     )

    //     await ethers.provider.send("evm_increaseTime", [25 * 24 * 60 * 60]); 

    //     // alice 已過鎖倉期限可以轉帳， 而 bob 還不能進行轉帳
    //     await expect(sharePrawn.connect(alice).transfer(charlie.address, 100000000)).to.emit(sharePrawn, "Transfer")
    //     await expect(sharePrawn.connect(bob).transfer(charlie.address, 100000000)).to.be.revertedWith(
    //         "not allowed to transfer until unlock stacking date",
    //     )
    // })

    // function testIncrement() public {
    //     counter.increment();
    //     assertEq(counter.number(), 1);
    // }

    // function testSetNumber(uint256 x) public {
    //     counter.setNumber(x);
    //     assertEq(counter.number(), x);
    // }

    
}