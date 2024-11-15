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

contract TheHook is BaseHook {
    using LPFeeLibrary for uint24;
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    error MustUseDynamicFee();

    // The default base fees we will charge
    uint24 public constant BASE_FEE = 3000; // 0.3%

    mapping(PoolId => uint256) public poolToBlockNumber;
    mapping(PoolId => uint160) public poolToSqrtPriceX96;

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
    ) external override returns (bytes4) {
        if (!key.fee.isDynamicFee()) revert MustUseDynamicFee();
        return this.beforeInitialize.selector;
    }

    function getFee(PoolId poolId) internal view returns (uint24) {
        uint160 currentSqrtPriceX96 = poolManager.(poolId).sqrtPriceX96;

        if (poolToSqrtPriceX96[poolId] > currentSqrtPriceX96) {
            poolToCurrentFeeDelta[poolId] = poolToSqrtPriceX96[poolId] - currentSqrtPriceX96;
            poolToCurrentFeeDeltaSign[poolId] = -1;
        } else {
            poolToCurrentFeeDelta[poolId] = currentSqrtPriceX96 - poolToSqrtPriceX96[poolId];
            poolToCurrentFeeDeltaSign[poolId] = 1;
        }

        poolToSqrtPriceX96[poolId] = currentSqrtPriceX96;
        
        return BASE_FEE;
    }

    function beforeSwap(
        address,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata,
        bytes calldata
    )
        external
        override
        onlyPoolManager
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        if (poolToBlockNumber[key.toId()] < block.number) {
            poolToBlockNumber[key.toId()] = block.number;
            poolToCurrentFeeDelta[key.toId()] = getFee();
            poolToCurrentFeeDeltaSign[key.toId()] = 1;
        }

        uint24 fee = poolToCurrentFeeDelta[key.toId()];

        uint24 feeWithFlag = fee | LPFeeLibrary.OVERRIDE_FEE_FLAG;
        return (
            this.beforeSwap.selector,
            BeforeSwapDeltaLibrary.ZERO_DELTA,
            feeWithFlag
        );
    }
}
