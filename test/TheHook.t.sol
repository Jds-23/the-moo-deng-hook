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
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";
import {FullMath} from "v4-core/libraries/FullMath.sol";
import {FixedPoint96} from "v4-core/libraries/FixedPoint96.sol";

import {console} from "forge-std/console.sol";

contract TestTheHook is Test, Deployers {
    using CurrencyLibrary for Currency;
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    TheHook hook;

    uint160 SQRT_PRICE_ALMOST_3000 = 4353199984070004262151157487616;

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
        deployCodeTo(
            "TheHook.sol",
            abi.encode(
                manager,
                address(0x2880aB155794e7179c9eE2e38200202908C17B43)
            ),
            hookAddress
        );
        hook = TheHook(hookAddress);

        uint256 currentPrice = FullMath.mulDiv(
            SQRT_PRICE_ALMOST_3000,
            SQRT_PRICE_ALMOST_3000,
            FullMath.mulDiv(FixedPoint96.Q96, FixedPoint96.Q96, hook.EXPONENT())
        );
        console.log("this out of hook currentPrice", currentPrice);

        // Initialize a pool
        (key, ) = initPool(
            currency0,
            currency1,
            hook,
            LPFeeLibrary.DYNAMIC_FEE_FLAG, // Set the `DYNAMIC_FEE_FLAG` in place of specifying a fixed fee
            SQRT_PRICE_ALMOST_3000
        );

        (uint160 sqrtPriceX96, int24 currentTick, , ) = manager.getSlot0(
            key.toId()
        );

        console.log("current sqrtPriceX96", sqrtPriceX96);

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
    }

    // function test_feeUpdatesWithGasPrice() public {
    //     // Set up our swap parameters
    //     PoolSwapTest.TestSettings memory testSettings = PoolSwapTest
    //         .TestSettings({takeClaims: false, settleUsingBurn: false});

    //     IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
    //         zeroForOne: true,
    //         amountSpecified: -0.00001 ether,
    //         sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
    //     });

    //     // Current gas price is 10 gwei
    //     // Moving average should also be 10
    //     uint128 gasPrice = uint128(tx.gasprice);
    //     uint128 movingAverageGasPrice = hook.movingAverageGasPrice();
    //     uint104 movingAverageGasPriceCount = hook.movingAverageGasPriceCount();
    //     assertEq(gasPrice, 10 gwei);
    //     assertEq(movingAverageGasPrice, 10 gwei);
    //     assertEq(movingAverageGasPriceCount, 1);

    //     // ----------------------------------------------------------------------
    //     // ----------------------------------------------------------------------
    //     // ----------------------------------------------------------------------
    //     // ----------------------------------------------------------------------

    //     // 1. Conduct a swap at gasprice = 10 gwei
    //     // This should just use `BASE_FEE` since the gas price is the same as the current average
    //     uint256 balanceOfToken1Before = currency1.balanceOfSelf();
    //     swapRouter.swap(key, params, testSettings, ZERO_BYTES);
    //     uint256 balanceOfToken1After = currency1.balanceOfSelf();
    //     uint256 outputFromBaseFeeSwap = balanceOfToken1After -
    //         balanceOfToken1Before;

    //     assertGt(balanceOfToken1After, balanceOfToken1Before);

    //     // Our moving average shouldn't have changed
    //     // only the count should have incremented
    //     movingAverageGasPrice = hook.movingAverageGasPrice();
    //     movingAverageGasPriceCount = hook.movingAverageGasPriceCount();
    //     assertEq(movingAverageGasPrice, 10 gwei);
    //     assertEq(movingAverageGasPriceCount, 2);

    //     // ----------------------------------------------------------------------
    //     // ----------------------------------------------------------------------
    //     // ----------------------------------------------------------------------
    //     // ----------------------------------------------------------------------

    //     // 2. Conduct a swap at lower gasprice = 4 gwei
    //     // This should have a higher transaction fees
    //     vm.txGasPrice(4 gwei);
    //     balanceOfToken1Before = currency1.balanceOfSelf();
    //     swapRouter.swap(key, params, testSettings, ZERO_BYTES);
    //     balanceOfToken1After = currency1.balanceOfSelf();

    //     uint256 outputFromIncreasedFeeSwap = balanceOfToken1After -
    //         balanceOfToken1Before;

    //     assertGt(balanceOfToken1After, balanceOfToken1Before);

    //     // Our moving average should now be (10 + 10 + 4) / 3 = 8 Gwei
    //     movingAverageGasPrice = hook.movingAverageGasPrice();
    //     movingAverageGasPriceCount = hook.movingAverageGasPriceCount();
    //     assertEq(movingAverageGasPrice, 8 gwei);
    //     assertEq(movingAverageGasPriceCount, 3);

    //     // ----------------------------------------------------------------------
    //     // ----------------------------------------------------------------------
    //     // ----------------------------------------------------------------------
    //     // ----------------------------------------------------------------------

    //     // 3. Conduct a swap at higher gas price = 12 gwei
    //     // This should have a lower transaction fees
    //     vm.txGasPrice(12 gwei);
    //     balanceOfToken1Before = currency1.balanceOfSelf();
    //     swapRouter.swap(key, params, testSettings, ZERO_BYTES);
    //     balanceOfToken1After = currency1.balanceOfSelf();

    //     uint outputFromDecreasedFeeSwap = balanceOfToken1After -
    //         balanceOfToken1Before;

    //     assertGt(balanceOfToken1After, balanceOfToken1Before);

    //     // Our moving average should now be (10 + 10 + 4 + 12) / 4 = 9 Gwei
    //     movingAverageGasPrice = hook.movingAverageGasPrice();
    //     movingAverageGasPriceCount = hook.movingAverageGasPriceCount();

    //     assertEq(movingAverageGasPrice, 9 gwei);
    //     assertEq(movingAverageGasPriceCount, 4);

    //     // ------

    //     // 4. Check all the output amounts

    //     console.log("Base Fee Output", outputFromBaseFeeSwap);
    //     console.log("Increased Fee Output", outputFromIncreasedFeeSwap);
    //     console.log("Decreased Fee Output", outputFromDecreasedFeeSwap);

    //     assertGt(outputFromDecreasedFeeSwap, outputFromBaseFeeSwap);
    //     assertGt(outputFromBaseFeeSwap, outputFromIncreasedFeeSwap);
    // }

    // function test_feeUpdatesWithBlockNumber() public {
    //     // Set up our swap parameters
    //     PoolSwapTest.TestSettings memory testSettings = PoolSwapTest
    //         .TestSettings({takeClaims: false, settleUsingBurn: false});

    //     IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
    //         zeroForOne: true,
    //         amountSpecified: -0.00001 ether,
    //         sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
    //     });

    //     // First swap at a normal block
    //     uint256 currentBlock = block.number;
    //     uint256 balanceOfToken1Before = currency1.balanceOfSelf();
    //     swapRouter.swap(key, params, testSettings, ZERO_BYTES);
    //     uint256 balanceOfToken1After = currency1.balanceOfSelf();
    //     uint256 outputFromBaseFeeSwap = balanceOfToken1After -
    //         balanceOfToken1Before;

    //     // Move to a block number divisible by 10 (should have higher fees)
    //     uint256 nextMultipleOf10 = ((currentBlock / 10) + 1) * 10;
    //     vm.roll(nextMultipleOf10);

    //     balanceOfToken1Before = currency1.balanceOfSelf();
    //     swapRouter.swap(key, params, testSettings, ZERO_BYTES);
    //     balanceOfToken1After = currency1.balanceOfSelf();
    //     uint256 outputFromHigherFeeSwap = balanceOfToken1After -
    //         balanceOfToken1Before;

    //     // Move to next block (should return to base fee)
    //     vm.roll(nextMultipleOf10 + 1);

    //     balanceOfToken1Before = currency1.balanceOfSelf();
    //     swapRouter.swap(key, params, testSettings, ZERO_BYTES);
    //     balanceOfToken1After = currency1.balanceOfSelf();
    //     uint256 outputFromNormalFeeSwap = balanceOfToken1After -
    //         balanceOfToken1Before;

    //     // Log the outputs for inspection
    //     console.log("Base Fee Output", outputFromBaseFeeSwap);
    //     console.log(
    //         "Higher Fee Output (block divisible by 10)",
    //         outputFromHigherFeeSwap
    //     );
    //     console.log("Normal Fee Output (next block)", outputFromNormalFeeSwap);

    //     // Higher fees should result in lower output amounts
    //     assertGt(outputFromBaseFeeSwap, outputFromHigherFeeSwap);

    //     // Check that normal fee swap is within 0.01% of base fee swap
    //     uint256 difference;
    //     if (outputFromBaseFeeSwap > outputFromNormalFeeSwap) {
    //         difference = outputFromBaseFeeSwap - outputFromNormalFeeSwap;
    //     } else {
    //         difference = outputFromNormalFeeSwap - outputFromBaseFeeSwap;
    //     }

    //     // Assert difference is less than 0.01% of the base output
    //     assertLt(difference * 10000, outputFromBaseFeeSwap);
    // }

    function test_priceUpdates() public {
        vm.deal(address(hook), 1 ether);
        bytes
            memory updateData = hex"504e41550100000003b801000000040d0033f3e8d590af837f6fdc2d7dfb76267894822992c57e14cf6a2997a0fdfd2bc1252e7e8def780308b19b10a06dc5c8bd7f2cf84a9c1aed7bd9f5302004555cea0002854b1305923b46b4740d96df410f9c37765f302dad7d024be690f7ddcd543ce61b974d7845083d0d4d5df91135f3193cbe4f1cc46f574abfe25483a64ca8f15e0103498e1d82adc424ca8bc2b7b7c7c8db49cf455a8d5cee55ab59d2a11a438e903537bcec4d8d40cbe2d016013305957a6d474dea17b860ec4f09978e84b8f278a70004ba347c1a5e33e5eecf5a5f7b2edb5e1db294e71afefadaef64c48cdbb6faefe01b4911e61e5b8aa6af19b42d131c72de11cc7c08091ad3e6983d85259df2d8bc0006d167a7f533e38ab20ed2137afe90c1289dbb02e5b5a159074baeea3174eab7a5530408f4efd4691a15e2a3b62430494cdfb4407de17ab9dfe64a4fc77cbb4ada0108ce8dbd634254dc9a8245b5d20cfc57d04adee63c808528dd0e4dcb76cf954e5d4f952ffaaf2c7167a6c621937b5789c1e6bccfed41bc00c18614efdaf4992afe010a84e61b51d5472b4dfb19b3684692437b58d2d10fdbefc5c6467a0ad155d352295906a6a52e8aa4e58fd36dfd47c10ab1a5a446bd944c76cf61791f5addf94c66010bb063f36ab84352eefa940b8b42897849a2e63a8e0f84496dadeff52ab268da82361d29ebd9d206230210efe4f6eff58fd6fcf65ea31dab098900aef7e3636e7f010cef3488f44a957bff04852fb9e3587c25dcf7d7e557bf8a500c1fcf4f6470c2b32ec6d2433809aea0294d561a2eaebbc52638dcff3fa46e95dab026592495572c000dc665acd17ccb271c987ac74e8d058f51304e93c01296c7de2624c0df092705071cf801aea5bcd66f5212fc8e5e81aaebc206dc6bd230806f6a0c393aca84ca97010ea43e1edf5d118f6f1ab659363c4bb1a413b3e24733020041e8f643c2dd4ca9281e5c18dd74e1e0b58137e6997240a7d531310eb3e81995922a9d00411c7945d700109e6746ab068db8728103f3693b20326ec87858bf2042ff5d3fcf527dc9046c29696f9727d2e0062f6ddf1f5393aa21262bee3028f75a54a05abefda3a30a28a1001121752fb3d5cf353e2ca0e5ae4c3e5d1183eeb9bf7189b4f4c7a742e39d3c61534bd7b88cb124f20ab7bfbe518963ee42327eb5e6dc0191bc1b83447bf9db42210167379eef00000000001ae101faedac5851e32b9b23b5f9411a8c2bac4aae3ed4dd7b811dd1a72ea4aa710000000005924b1b014155575600000000000a9f15bd000027104677fb6b31f63465fddc1cda714d08fb9794427401005500ff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace000000466cc4b899000000000926d84afffffff80000000067379eef0000000067379eef00000046938752b00000000009c01cb20b7889832f2f3c7ccef303d06f838712a5640d953705869774ce6b43ecd990f55c351d4237c36a5a734813bfdc19e217d64b153e3b82952524311c3edebdb9d0e4ad77b5f2291c16aebe35f27759252ae3dbad0ec52a577fb9585b656754ff328c971307204a0742f6dbf169a2a4db742f11dfa736f20ab8173a4968e2caecfa6c785e389d60efe8a9af257e6b7eb4b2d273ee4a4bdb07aacd71928cc27038035d23e354a48ea125760b5fd303124b71e6433f9ca82981cd99625f08034e1ed1ecabf5468e9dd523765846d6dc74bef69626727ba07e4e8b363ea87b70";
        bytes[] memory updates = new bytes[](1);
        updates[0] = updateData;
        (uint24 fee, int8 deltaSign) = hook.getFee(
            key.toId(),
            abi.encode(updates)
        );
        console.log("fee", fee);
        console.log("deltaSign", deltaSign);
    }
}
