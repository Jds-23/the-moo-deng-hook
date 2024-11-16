// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {BaseHook} from "v4-periphery/src/base/hooks/BaseHook.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {LPFeeLibrary} from "v4-core/libraries/LPFeeLibrary.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/types/BeforeSwapDelta.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";
import {FullMath} from "v4-core/libraries/FullMath.sol";
import {SafeCast} from "v4-core/libraries/SafeCast.sol";
import {console} from "forge-std/console.sol";

contract TheHook is BaseHook {
    using LPFeeLibrary for uint24;
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    error MustUseDynamicFee();

    // The default base fees we will charge
    uint24 public constant BASE_FEE = 3000; // 0.3%
    uint256 public constant MULTIPLIER = 7500; // 0.75%
    uint24 public constant MULTIPLIER_DIVISOR = 1000000;

    mapping(PoolId => uint256) public poolToLastUpdatedBN;
    mapping(PoolId => uint160) public poolToPrvSqrtPriceX96;

    mapping(PoolId => uint24) public poolToCurrentFeeDelta;
    mapping(PoolId => int8) public poolToCurrentFeeDeltaSign;

    constructor(IPoolManager poolManager) BaseHook(poolManager) {}

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
    ) external pure override returns (bytes4) {
        if (!key.fee.isDynamicFee()) revert MustUseDynamicFee();
        return this.beforeInitialize.selector;
    }

    function setFee(PoolId poolId) internal {
        (uint160 currentSqrtPriceX96, , , ) = poolManager.getSlot0(poolId);

        if (currentSqrtPriceX96 == poolToPrvSqrtPriceX96[poolId]) {
            return;
        }

        if (poolToPrvSqrtPriceX96[poolId] == 0) {
            poolToPrvSqrtPriceX96[poolId] = currentSqrtPriceX96;
            poolToCurrentFeeDelta[poolId] = 0;
            return;
        }

        uint160 sqrtPriceDelta = 0;

        if (poolToPrvSqrtPriceX96[poolId] > currentSqrtPriceX96) {
            sqrtPriceDelta =
                poolToPrvSqrtPriceX96[poolId] -
                currentSqrtPriceX96;
            poolToCurrentFeeDeltaSign[poolId] = -1;
        } else {
            sqrtPriceDelta =
                currentSqrtPriceX96 -
                poolToPrvSqrtPriceX96[poolId];
            poolToCurrentFeeDeltaSign[poolId] = 1;
        }

        // fee = fee - c*delta, where c is a constant
        uint256 feeToChange = FullMath.mulDiv(
            MULTIPLIER,
            poolToCurrentFeeDelta[poolId],
            MULTIPLIER_DIVISOR
        );

        if (feeToChange >= uint256(BASE_FEE)) {
            poolToCurrentFeeDelta[poolId] = BASE_FEE;
        } else {
            // if poolToCurrentFeeDelta a uint256 is less than BASE_FEE a uint24, there should no value loss by downcasting
            poolToCurrentFeeDelta[poolId] = uint24(feeToChange);
        }

        poolToPrvSqrtPriceX96[poolId] = currentSqrtPriceX96;
    }

    function beforeSwap(
        address,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        bytes calldata
    )
        external
        override
        onlyPoolManager
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        if (poolToLastUpdatedBN[key.toId()] < block.number) {
            poolToLastUpdatedBN[key.toId()] = block.number;
            setFee(key.toId());
        }

        uint24 fee = BASE_FEE;
        if (params.zeroForOne) {
            if (poolToCurrentFeeDeltaSign[key.toId()] == -1) {
                fee = fee + poolToCurrentFeeDelta[key.toId()];
            } else {
                fee = fee - poolToCurrentFeeDelta[key.toId()];
            }
        } else {
            if (poolToCurrentFeeDeltaSign[key.toId()] == 1) {
                fee = fee + poolToCurrentFeeDelta[key.toId()];
            } else {
                fee = fee - poolToCurrentFeeDelta[key.toId()];
            }
        }

        uint24 feeWithFlag = fee | LPFeeLibrary.OVERRIDE_FEE_FLAG;
        return (
            this.beforeSwap.selector,
            BeforeSwapDeltaLibrary.ZERO_DELTA,
            feeWithFlag
        );
    }
}
