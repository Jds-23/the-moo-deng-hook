// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {BaseHook} from "v4-periphery/src/base/hooks/BaseHook.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";

import {PoolKey} from "v4-core/types/PoolKey.sol";
import {LPFeeLibrary} from "v4-core/libraries/LPFeeLibrary.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/types/BeforeSwapDelta.sol";
import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {FullMath} from "v4-core/libraries/FullMath.sol";
import {FixedPoint96} from "v4-core/libraries/FixedPoint96.sol";
import {SqrtPriceMath} from "v4-core/libraries/SqrtPriceMath.sol";
import {Time} from "openzeppelin-contracts/contracts/utils/types/Time.sol";

import {console} from "forge-std/console.sol";

contract TheHook is BaseHook {
    using LPFeeLibrary for uint24;
    using StateLibrary for IPoolManager;
    using PoolIdLibrary for PoolKey;

    error MustUseDynamicFee();

    IPyth pyth;
    // The default base fees we will charge
    uint24 public constant BASE_FEE = 3000; // 0.3%

    uint48 public LAST_UPDATE_TIME = 0;
    uint8 public PRICE_UPDATE_INTERVAL = 60;
    uint256 public LAST_PULLED_PRICE;
    uint256 public EXPONENT = 1_0000_0000;

    constructor(IPoolManager poolManager, address _pyth) BaseHook(poolManager) {
        pyth = IPyth(_pyth);
    }

    function getHookPermissions()
        public
        pure
        override
        returns (Hooks.Permissions memory)
    {
        return
            Hooks.Permissions({
                beforeInitialize: true, // we need to set the initial fee
                afterInitialize: false,
                beforeAddLiquidity: false,
                beforeRemoveLiquidity: false,
                afterAddLiquidity: false,
                afterRemoveLiquidity: false,
                beforeSwap: true, // we need to set the dynamic fee
                afterSwap: false,
                beforeDonate: false,
                afterDonate: false,
                beforeSwapReturnDelta: false,
                afterSwapReturnDelta: false,
                afterAddLiquidityReturnDelta: false,
                afterRemoveLiquidityReturnDelta: false
            });
    }

    function beforeInitialize(
        address,
        PoolKey calldata key,
        uint160
    ) external override returns (bytes4) {
        if (!key.fee.isDynamicFee()) revert MustUseDynamicFee();
        return this.beforeInitialize.selector;
    }

    function getFee(
        PoolId poolId,
        bytes calldata data
    ) public returns (uint24, int8) {
        (uint160 currentsqrtPriceXA96, , , ) = poolManager.getSlot0(poolId);
        uint256 currentPrice = FullMath.mulDiv(
            currentsqrtPriceXA96,
            currentsqrtPriceXA96,
            FullMath.mulDiv(FixedPoint96.Q96, FixedPoint96.Q96, EXPONENT)
        );

        uint48 currentTime = Time.timestamp();
        if (currentTime - LAST_UPDATE_TIME > 60) {
            bytes[] memory priceUpdate = abi.decode(data, (bytes[]));
            uint256 cexPrice = uint256(uint64(getPriceFrom(priceUpdate)));
            // uint256 cexPrice = 1000000000000000000;
            LAST_PULLED_PRICE = cexPrice;
            LAST_UPDATE_TIME = currentTime;
        }
        uint256 delta = 0;
        int8 deltaSign = 0;
        if (LAST_PULLED_PRICE > currentPrice) {
            delta = LAST_PULLED_PRICE - currentPrice;
            deltaSign = 1;
        } else {
            delta = currentPrice - LAST_PULLED_PRICE;
            deltaSign = -1;
        }

        if (delta == 0) {
            return (BASE_FEE, deltaSign);
        }

        console.log("delta", delta);
        console.log("this in hook currentPrice", currentPrice);
        console.log("LAST_PULLED_PRICE", LAST_PULLED_PRICE);

        return (BASE_FEE + uint24(delta / PRICE_UPDATE_INTERVAL), deltaSign);
    }

    function beforeSwap(
        address,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        bytes calldata data
    )
        external
        override
        onlyPoolManager
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        (uint24 fee, int8 deltaSign) = getFee(key.toId(), data);

        uint24 feeWithFlag = fee | LPFeeLibrary.OVERRIDE_FEE_FLAG;
        return (
            this.beforeSwap.selector,
            BeforeSwapDeltaLibrary.ZERO_DELTA,
            feeWithFlag
        );
    }

    function getPriceFrom(
        bytes[] memory priceUpdate
    ) public payable returns (int64) {
        uint fee = pyth.getUpdateFee(priceUpdate);
        pyth.updatePriceFeeds{value: fee}(priceUpdate);

        bytes32 priceFeedId = 0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace; // to be dynamic
        PythStructs.Price memory price = pyth.getPriceNoOlderThan(
            priceFeedId,
            60
        );
        console.log(price.expo);
        return price.price;
    }
}
