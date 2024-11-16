// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {PoolManager} from "v4-core/PoolManager.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {LPFeeLibrary} from "v4-core/libraries/LPFeeLibrary.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";
import {TheHook} from "../src/TheHook.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {console} from "forge-std/console.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";

contract TestTheHook is Test, Deployers {
    using CurrencyLibrary for Currency;
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    TheHook hook;

    PoolKey standardPoolKey;

    uint24 public constant BASE_FEE = 3000; // 0.3%

    function setUp() public {
        // Deploy v4-core
        deployFreshManagerAndRouters();

        // Deploy, mint tokens, and approve all periphery contracts for two tokens
        deployMintAndApprove2Currencies();

        // Deploy our hook with the proper flags
        address hookAddress = address(
            uint160(Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_SWAP_FLAG)
        );

        // Set gas price = 10 gwei and deploy our hook
        vm.txGasPrice(10 gwei);
        deployCodeTo("TheHook.sol", abi.encode(manager), hookAddress);
        hook = TheHook(hookAddress);

        // Initialize a pool
        (key, ) = initPool(
            currency0,
            currency1,
            hook,
            LPFeeLibrary.DYNAMIC_FEE_FLAG, // Set the `DYNAMIC_FEE_FLAG` in place of specifying a fixed fee
            SQRT_PRICE_1_1
        );

        // Initialize a pool
        (standardPoolKey, ) = initPool(
            currency0,
            currency1,
            IHooks(address(0)),
            BASE_FEE, // Set the `BASE_FEE` as a fixed fee
            SQRT_PRICE_1_1
        );

        // Add some liquidity
        modifyLiquidityRouter.modifyLiquidity(
            key,
            IPoolManager.ModifyLiquidityParams({
                tickLower: -60,
                tickUpper: 60,
                liquidityDelta: 100 ether,
                salt: bytes32(0)
            }),
            ZERO_BYTES
        );

        // Add some liquidity
        modifyLiquidityRouter.modifyLiquidity(
            standardPoolKey,
            IPoolManager.ModifyLiquidityParams({
                tickLower: -60,
                tickUpper: 60,
                liquidityDelta: 100 ether,
                salt: bytes32(0)
            }),
            ZERO_BYTES
        );
    }

    function test_feeForFirstSwapShouldBeBaseFee() public {
        // Set up swap parameters
        PoolSwapTest.TestSettings memory testSettings = PoolSwapTest
            .TestSettings({takeClaims: false, settleUsingBurn: false});

        // Get the pool ID and initial state
        PoolId poolId = key.toId();
        (uint160 sqrtPriceX96Before, , , ) = manager.getSlot0(poolId);
        uint256 balanceOfToken1Before = currency1.balanceOfSelf();

        int256 amountSpecified = -0.01 ether;
        // Perform the swap
        (BalanceDelta result, BalanceDelta standardPoolResult) = swap(
            true,
            amountSpecified,
            TickMath.MIN_SQRT_PRICE + 1,
            testSettings
        );

        // Get post-swap state
        (uint160 sqrtPriceX96After, , , ) = manager.getSlot0(poolId);
        uint256 balanceOfToken1After = currency1.balanceOfSelf();
        uint24 currentFeeDelta = hook.poolToCurrentFeeDelta(poolId);

        // Verify the swap was successful
        assertGt(
            balanceOfToken1After,
            balanceOfToken1Before,
            "Swap should increase token1 balance"
        );
        assertLt(
            sqrtPriceX96After,
            sqrtPriceX96Before,
            "Price should decrease for zeroForOne swap"
        );
        // Verify currentFeeDelta is zero
        assertEq(currentFeeDelta, 0, "Fee Delta should be zero");
        assertEq(result.amount0(), amountSpecified);
        assertEq(
            standardPoolResult.amount1(),
            result.amount1(),
            "Same fee should have been charged"
        );
    }

    function test_feeForSwapInSecondBlockShouldBeDynamicFee() public {
        // Set up swap parameters
        PoolSwapTest.TestSettings memory testSettings = PoolSwapTest
            .TestSettings({takeClaims: false, settleUsingBurn: false});

        // Get the pool ID and initial state
        PoolId poolId = key.toId();

        (uint160 sqrtPriceX96BeforeFirstSwap, , , ) = manager.getSlot0(poolId);
        // Perform the first swap
        swap(true, -0.01 ether, TickMath.MIN_SQRT_PRICE + 1, testSettings);

        // jump +1 block
        vm.roll(block.number + 1);

        // fetch prvSqrtPriceX96
        uint160 prvSqrtPriceX96 = hook.poolToPrvSqrtPriceX96(poolId);

        // assert sqrtPriceX96BeforeFirstSwap should be equal to prvSqrtPriceX96
        assertEq(
            sqrtPriceX96BeforeFirstSwap,
            prvSqrtPriceX96,
            "sqrtPriceX96BeforeFirstSwap should be equal to prvSqrtPriceX96"
        );

        (uint160 sqrtPriceX96BeforeSecondSwap, , , ) = manager.getSlot0(poolId);
        uint256 balanceOfToken1Before = currency1.balanceOfSelf();

        int256 amountSpecified = -0.01 ether;
        // Perform the second swap
        (BalanceDelta result, ) = swap(
            true,
            amountSpecified,
            TickMath.MIN_SQRT_PRICE + 1,
            testSettings
        );

        // Get post-swap state
        (uint160 sqrtPriceX96AfterSecondSwap, , , ) = manager.getSlot0(poolId);
        uint256 balanceOfToken1After = currency1.balanceOfSelf();
        uint24 currentFeeDelta = hook.poolToCurrentFeeDelta(poolId);

        assertEq(result.amount0(), amountSpecified);

        // Verify the swap was successful
        assertGt(
            balanceOfToken1After,
            balanceOfToken1Before,
            "Swap should increase token1 balance"
        );
        assertLt(
            sqrtPriceX96AfterSecondSwap,
            sqrtPriceX96BeforeSecondSwap,
            "Price should decrease for zeroForOne swap"
        );
        // Verify currentFeeDelta is not zero
        assertNotEq(currentFeeDelta, 0, "Fee Delta should not be zero");
    }

    function test_feeForSwapInSecondBlockShouldBeMoreInDynamicFeePoolForSameDirection()
        public
    {
        // Set up swap parameters
        PoolSwapTest.TestSettings memory testSettings = PoolSwapTest
            .TestSettings({takeClaims: false, settleUsingBurn: false});

        // Perform the first pool swap
        swap(true, -0.01 ether, TickMath.MIN_SQRT_PRICE + 1, testSettings);

        // jump +1 block
        vm.roll(block.number + 1);

        int256 amountSpecified = -0.01 ether;

        // Perform the second pool swap
        (BalanceDelta result, BalanceDelta standardPoolResult) = swap(
            true,
            amountSpecified,
            TickMath.MIN_SQRT_PRICE + 1,
            testSettings
        );

        assertLt(
            result.amount1(),
            standardPoolResult.amount1(),
            "Dynamic fee pool should charge more fee"
        );
    }

    function test_feeForSwapInSecondBlockShouldBeLessInDynamicFeePoolForOppositeDirection()
        public
    {
        // Set up swap parameters
        PoolSwapTest.TestSettings memory testSettings = PoolSwapTest
            .TestSettings({takeClaims: false, settleUsingBurn: false});

        // Perform the first pool swap
        swap(true, -0.01 ether, TickMath.MIN_SQRT_PRICE + 1, testSettings);

        // jump +1 block
        vm.roll(block.number + 1);

        int256 amountSpecified = -1000;

        // Perform the second pool swap
        (BalanceDelta result, BalanceDelta standardPoolResult) = swap(
            false,
            amountSpecified,
            TickMath.MAX_SQRT_PRICE - 1,
            testSettings
        );

        assertGt(
            result.amount0(),
            standardPoolResult.amount0(),
            "Dynamic fee pool should charge more fee"
        );
    }

    function swap(
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        PoolSwapTest.TestSettings memory testSettings
    ) public returns (BalanceDelta, BalanceDelta) {
        // copy same trade to dynamic hook pool and a standard pool
        return (
            swap(
                zeroForOne,
                amountSpecified,
                sqrtPriceLimitX96,
                testSettings,
                key
            ),
            swap(
                zeroForOne,
                amountSpecified,
                sqrtPriceLimitX96,
                testSettings,
                standardPoolKey
            )
        );
    }

    function swap(
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        PoolSwapTest.TestSettings memory testSettings,
        PoolKey memory _key
    ) public returns (BalanceDelta) {
        IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: amountSpecified,
            sqrtPriceLimitX96: sqrtPriceLimitX96
        });
        return swapRouter.swap(_key, params, testSettings, ZERO_BYTES);
    }
}
