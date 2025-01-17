// //SPDX-License-Identifier: Unlicense
// pragma solidity ^0.8.7;

// import "./hardhat/console.sol";

// // ----------------------INTERFACE------------------------------

// // Aave
// // https://docs.aave.com/developers/the-core-protocol/lendingpool/ilendingpool

// interface ILendingPool {
//     /**
//      * Function to liquidate a non-healthy position collateral-wise, with Health Factor below 1
//      * - The caller (liquidator) covers `debtToCover` amount of debt of the user getting liquidated, and receives
//      *   a proportionally amount of the `collateralAsset` plus a bonus to cover market risk
//      * @param collateralAsset The address of the underlying asset used as collateral, to receive as result of theliquidation
//      * @param debtAsset The address of the underlying borrowed asset to be repaid with the liquidation
//      * @param user The address of the borrower getting liquidated
//      * @param debtToCover The debt amount of borrowed `asset` the liquidator wants to cover
//      * @param receiveAToken `true` if the liquidators wants to receive the collateral aTokens, `false` if he wants
//      * to receive the underlying collateral asset directly
//      **/
//     function liquidationCall(
//         address collateralAsset,
//         address debtAsset,
//         address user,
//         uint256 debtToCover,
//         bool receiveAToken
//     ) external;

//     /**
//      * Returns the user account data across all the reserves
//      * @param user The address of the user
//      * @return totalCollateralETH the total collateral in ETH of the user
//      * @return totalDebtETH the total debt in ETH of the user
//      * @return availableBorrowsETH the borrowing power left of the user
//      * @return currentLiquidationThreshold the liquidation threshold of the user
//      * @return ltv the loan to value of the user
//      * @return healthFactor the current health factor of the user
//      **/
//     function getUserAccountData(address user)
//         external
//         view
//         returns (
//             uint256 totalCollateralETH,
//             uint256 totalDebtETH,
//             uint256 availableBorrowsETH,
//             uint256 currentLiquidationThreshold,
//             uint256 ltv,
//             uint256 healthFactor
//         );
// }

// // UniswapV2

// // https://github.com/Uniswap/v2-core/blob/master/contracts/interfaces/IERC20.sol
// // https://docs.uniswap.org/protocol/V2/reference/smart-contracts/Pair-ERC-20
// interface IERC20 {
//     // Returns the account balance of another account with address _owner.
//     function balanceOf(address owner) external view returns (uint256);

//     /**
//      * Allows _spender to withdraw from your account multiple times, up to the _value amount.
//      * If this function is called again it overwrites the current allowance with _value.
//      * Lets msg.sender set their allowance for a spender.
//      **/
//     function approve(address spender, uint256 value) external; // return type is deleted to be compatible with USDT

//     /**
//      * Transfers _value amount of tokens to address _to, and MUST fire the Transfer event.
//      * The function SHOULD throw if the message caller’s account balance does not have enough tokens to spend.
//      * Lets msg.sender send pool tokens to an address.
//      **/
//     function transfer(address to, uint256 value) external returns (bool);
// }

// // https://github.com/Uniswap/v2-periphery/blob/master/contracts/interfaces/IWETH.sol
// interface IWETH is IERC20 {
//     // Convert the wrapped token back to Ether.
//     function withdraw(uint256) external;
// }

// // https://github.com/Uniswap/v2-core/blob/master/contracts/interfaces/IUniswapV2Callee.sol
// // The flash loan liquidator we plan to implement this time should be a UniswapV2 Callee
// interface IUniswapV2Callee {
//     function uniswapV2Call(
//         address sender,
//         uint256 amount0,
//         uint256 amount1,
//         bytes calldata data
//     ) external;
// }

// // https://github.com/Uniswap/v2-core/blob/master/contracts/interfaces/IUniswapV2Factory.sol
// // https://docs.uniswap.org/protocol/V2/reference/smart-contracts/factory
// interface IUniswapV2Factory {
//     // Returns the address of the pair for tokenA and tokenB, if it has been created, else address(0).
//     function getPair(address tokenA, address tokenB)
//         external
//         view
//         returns (address pair);
// }

// // https://github.com/Uniswap/v2-core/blob/master/contracts/interfaces/IUniswapV2Pair.sol
// // https://docs.uniswap.org/protocol/V2/reference/smart-contracts/pair
// interface IUniswapV2Pair {
//     /**
//      * Swaps tokens. For regular swaps, data.length must be 0.
//      * Also see [Flash Swaps](https://docs.uniswap.org/protocol/V2/concepts/core-concepts/flash-swaps).
//      **/
//     function swap(
//         uint256 amount0Out,
//         uint256 amount1Out,
//         address to,
//         bytes calldata data
//     ) external;

//     /**
//      * Returns the reserves of token0 and token1 used to price trades and distribute liquidity.
//      * See Pricing[https://docs.uniswap.org/protocol/V2/concepts/advanced-topics/pricing].
//      * Also returns the block.timestamp (mod 2**32) of the last block during which an interaction occured for the pair.
//      **/
//     function getReserves()
//         external
//         view
//         returns (
//             uint112 reserve0,
//             uint112 reserve1,
//             uint32 blockTimestampLast
//         );
// }

// // ----------------------IMPLEMENTATION------------------------------

// contract LiquidationOperator is IUniswapV2Callee {
//     uint8 public constant health_factor_decimals = 18;

//     // TODO: define constants used in the contract including ERC-20 tokens, Uniswap Pairs, Aave lending pools, etc. */

//     address aave;
//     address WBTC;
//     address USDT;
//     address WETH;
//     address ETH;
//     address uniswapFactoryV2;

//     address target;
//     uint debt;


//     ILendingPool lendingPool;
//     IERC20 wbtc;
//     IERC20 usdt;
//     IWETH weth;
//     IUniswapV2Pair usdtWbtcPair;
//     IUniswapV2Pair wethUsdtPair;
//     IUniswapV2Pair wethWbtcPair;

//     //    *** Your code here ***
//     // END TODO

//     // some helper function, it is totally fine if you can finish the lab without using these function
//     // https://github.com/Uniswap/v2-periphery/blob/master/contracts/libraries/UniswapV2Library.sol
//     // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
//     // safe mul is not necessary since https://docs.soliditylang.org/en/v0.8.9/080-breaking-changes.html
//     function getAmountOut(
//         uint256 amountIn,
//         uint256 reserveIn,
//         uint256 reserveOut
//     ) internal pure returns (uint256 amountOut) {
//         require(amountIn > 0, "UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT");
//         require(
//             reserveIn > 0 && reserveOut > 0,
//             "UniswapV2Library: INSUFFICIENT_LIQUIDITY"
//         );
//         uint256 amountInWithFee = amountIn * 997;
//         uint256 numerator = amountInWithFee * reserveOut;
//         uint256 denominator = reserveIn * 1000 + amountInWithFee;
//         amountOut = numerator / denominator;

//     }

//     // some helper function, it is totally fine if you can finish the lab without using these function
//     // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
//     // safe mul is not necessary since https://docs.soliditylang.org/en/v0.8.9/080-breaking-changes.html
//     function getAmountIn(
//         uint256 amountOut,
//         uint256 reserveIn,
//         uint256 reserveOut
//     ) internal pure returns (uint256 amountIn) {
//         require(amountOut > 0, "UniswapV2Library: INSUFFICIENT_OUTPUT_AMOUNT");
//         require(
//             reserveIn > 0 && reserveOut > 0,
//             "UniswapV2Library: INSUFFICIENT_LIQUIDITY"
//         );
//         uint256 numerator = reserveIn * amountOut * 1000;
//         uint256 denominator = (reserveOut - amountOut) * 997;
//         amountIn = (numerator / denominator) + 1;
//     }

//     constructor() {
//         aave = address(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9);
//         WBTC = address(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
//         USDT = address(0xdAC17F958D2ee523a2206206994597C13D831ec7);
//         WETH = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
//         uniswapFactoryV2 = address(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);
//         target = address(0x59CE4a2AC5bC3f5F225439B2993b86B42f6d3e9F);

//         lendingPool = ILendingPool(aave);
//         wbtc = IERC20(WBTC);
//         usdt = IERC20(USDT);
//         weth = IWETH(WETH);
//         usdtWbtcPair = IUniswapV2Pair(IUniswapV2Factory(uniswapFactoryV2).getPair(USDT, WBTC));
//         wethUsdtPair = IUniswapV2Pair(IUniswapV2Factory(uniswapFactoryV2).getPair(USDT, WETH));
//         wethWbtcPair = IUniswapV2Pair(IUniswapV2Factory(uniswapFactoryV2).getPair(WETH, WBTC));
//     }

//     receive() external payable {
//         assert(msg.sender == WETH);
//     }

//     // required by the testing script, entry for your liquidation call
//     function operate() external {

//         //LIQUIDATION_CLOSE_FACTOR_PERCENT = 50 
//         //    .userCompoundedBorrowBalance
//         //    .mul(LIQUIDATION_CLOSE_FACTOR_PERCENT)
//         //    .div(100);
        
//         // 0. security checks and initializing variables

//         // 1. get the target user account data & make sure it is liquidatable
//         uint256 totalDebtETH;

//         {
//         uint256 totalCollateralETH;
//         uint256 availableBorrowsETH;
//         uint256 currentLiquidationThreshold;
//         uint256 ltv;
//         uint256 healthFactor;    
//         (totalCollateralETH,
//         totalDebtETH,
//         availableBorrowsETH,
//         currentLiquidationThreshold, ltv, healthFactor) = lendingPool.getUserAccountData(target);
//         console.log("totalCollateralETH", totalCollateralETH);
//         console.log("totalDebtETH", totalDebtETH);
//         console.log("availableBorrowsETH", availableBorrowsETH);
//         console.log("currentLiquidationThreshold", currentLiquidationThreshold);
//         console.log("ltv", ltv);
//         console.log("Health factor", healthFactor);
//         }
//         debt = totalDebtETH;

//         uint112 reserve0;
//         uint112 reserve1;
//         (reserve0, reserve1, ) = usdtWbtcPair.getReserves();

//         console.log("token wbtc", reserve0);
//         console.log("token wbtc", wbtc.balanceOf(IUniswapV2Factory(uniswapFactoryV2).getPair(USDT, WBTC)));

//         console.log("token usdt", reserve1);
//         console.log("token usdt", usdt.balanceOf(IUniswapV2Factory(uniswapFactoryV2).getPair(USDT, WBTC)));

//         uint112 wethR;
//         uint112 usdtR;
//         (wethR, usdtR, )= wethUsdtPair.getReserves();
//         console.log("token weth", wethR);
//         console.log("token weth", weth.balanceOf(IUniswapV2Factory(uniswapFactoryV2).getPair(USDT, WETH)));
        
//         console.log("token usdt", usdtR);
//         console.log("token usdt", usdt.balanceOf(IUniswapV2Factory(uniswapFactoryV2).getPair(USDT, WETH)));
     
//         uint112 wethWbtcR0;
//         uint112 wethWbtcR1;
//         (wethWbtcR0, wethWbtcR1, )= wethWbtcPair.getReserves();
//         console.log("token weth", wethWbtcR1);
//         console.log("token weth", weth.balanceOf(IUniswapV2Factory(uniswapFactoryV2).getPair(WETH, WBTC)));
        
//         console.log("token wbtc", wethWbtcR0);
//         console.log("token wbtc", wbtc.balanceOf(IUniswapV2Factory(uniswapFactoryV2).getPair(WETH, WBTC)));


//         console.log("AmountIn weth usdt", getAmountOut(totalDebtETH * 50 / 100 ,wethR ,usdtR));
//         uint aout = getAmountOut(totalDebtETH * 50 / 100 ,wethR ,usdtR);
//         bytes memory data = abi.encode(USDT, usdtR);
//         console.log("AmountIn usdt weth", getAmountIn(2916378221684 ,wethR ,usdtR));


//         //13362637187811
//         //2916378221684

//         //Colla
//         //10630629178819327381450
//         //total debt
//         //8093660057205842670564
//         //Liquiable eth
//         //1504965363370543592245
//         // 2. call flash swap to liquidate the target user
//         // wethUsdtPair.swap(0, 2916378221684, address(this), data);
//         wethUsdtPair.swap(0, 2916378221684, address(this), data);


//         // 3. Convert the profit into ETH and send back to sender
//         console.log(weth.balanceOf(address(this)));
//         uint wethBalance = weth.balanceOf(address(this));
//         console.log("HEY");
//         weth.withdraw(wethBalance);
//         console.log("HEY");
//         console.log(address(this).balance);
//         payable(msg.sender).transfer(address(this).balance);
    

//         // END TODO
//     }

//     // required by the swap
//     function uniswapV2Call(
//         address,
//         uint256,
//         uint256 amount1,
//         bytes calldata
//     ) external override {
//         // 2.0. security checks and initializing variables

//         console.log(msg.sender);

//         console.log(amount1);
//         console.log("token wbtc", wbtc.balanceOf(address(this)));
//         console.log("token usdt", usdt.balanceOf(address(this)));
//         console.log("token weth", weth.balanceOf(address(this)));

//         usdt.approve(aave, amount1);
//         // 2.1 liquidate the target user

//         lendingPool.liquidationCall(WBTC, USDT, target, amount1, false);
//         console.log("token wbtc", wbtc.balanceOf(address(this)));
//         console.log("token usdt", usdt.balanceOf(address(this)));
//         console.log("token weth", weth.balanceOf(address(this)));

//         {
//         uint256 totalDebtETH;
//         uint256 totalCollateralETH;
//         uint256 availableBorrowsETH;
//         uint256 currentLiquidationThreshold;
//         uint256 ltv;
//         uint256 healthFactor;    
//         (totalCollateralETH,
//         totalDebtETH,
//         availableBorrowsETH,
//         currentLiquidationThreshold, ltv, healthFactor) = lendingPool.getUserAccountData(target);
//         console.log("totalCollateralETH", totalCollateralETH);
//         console.log("totalDebtETH", totalDebtETH);
//         console.log("availableBorrowsETH", availableBorrowsETH);
//         console.log("currentLiquidationThreshold", currentLiquidationThreshold);
//         console.log("ltv", ltv);
//         console.log("Health factor", healthFactor);
//         }

//         uint112 wbtcR1;
//         uint112 wethR1;

//         uint priceDiff = amount1;
//         console.log(priceDiff);
//         (wbtcR1, wethR1, ) = wethWbtcPair.getReserves();

//         uint swapBalance = wbtc.balanceOf(address(this));
//         uint ethAmount = getAmountOut(swapBalance, wbtcR1, wethR1);
//         // 2.2 swap WBTC for other things or repay directly
//         wbtc.transfer(IUniswapV2Factory(uniswapFactoryV2).getPair(WETH, WBTC), swapBalance);
//         wethWbtcPair.swap(0, ethAmount, address(this), new bytes(0));
//         console.log("token wbtc", wbtc.balanceOf(address(this)));
//         console.log("token weth", weth.balanceOf(address(this)));
//         console.log("token usdt", usdt.balanceOf(address(this)));

//         // getAmountOut(swapBalance ,wethR ,usdtR)

//         uint112 wethR2;
//         uint112 usdtR2;
//         (wethR2, usdtR2, )= wethUsdtPair.getReserves();
//         console.log(wethR2);
//         console.log(usdtR2);
//         uint repayAmountEth = getAmountIn(priceDiff, wethR2, usdtR2);
//         // uint repayAmountEth = getAmountIn(amount1 ,wethR2, usdtR2);
//         console.log(repayAmountEth);

//         console.log("Get amount pass");
        
//         // 2.3 repay
//         weth.transfer(msg.sender, repayAmountEth);
//         console.log("Repay eth amount pass");
//         console.log("Repay usdt amount pass");

//         console.log("token wbtc", wbtc.balanceOf(address(this)));
//         console.log("token weth", weth.balanceOf(address(this)));
//         console.log("token usdt", usdt.balanceOf(address(this)));

//     }
// }
