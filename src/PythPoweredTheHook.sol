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
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {FixedPoint96} from "v4-core/libraries/FixedPoint96.sol";
import {SqrtPriceMath} from "v4-core/libraries/SqrtPriceMath.sol";
import {Time} from "@openzeppelin/contracts/utils/types/Time.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";

contract PythPoweredTheHook is BaseHook, Ownable {
    using LPFeeLibrary for uint24;
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    error MustUseDynamicFee();
    error MustSetPriceFeed();

    IPyth pyth;
    // The default base fees we will charge
    uint24 public constant BASE_FEE = 3000; // 0.3%
    uint256 public constant MULTIPLIER = 7500; // 0.75%
    uint24 public constant MULTIPLIER_DIVISOR = 1000000;
    uint48 public constant TOLERABLE_DELAY_SEC = 10; // ideal should be less 400ms i.e TOLERABLE_DELAY_SEC = 0, but okay 😄
    uint256 public EXPONENT = 1_0000_0000;

    mapping(PoolId => uint256) public poolToLastUpdatedBN;
    mapping(PoolId => uint160) public poolToPrvSqrtPriceX96;

    mapping(PoolId => uint24) public poolToCurrentFeeDelta;
    mapping(PoolId => int8) public poolToCurrentFeeDeltaSign;

    bytes32 priceFeedId = bytes32(0);

    constructor(
        IPoolManager poolManager,
        address _pyth
    ) BaseHook(poolManager) Ownable(msg.sender) {
        pyth = IPyth(_pyth);
    }

    function setPriceFeedId(bytes32 _priceFeedId) external onlyOwner {
        priceFeedId = _priceFeedId;
    }

    function getHookPermissions()
        public
        pure
        override
        returns (Hooks.Permissions memory)
    {
        return
            Hooks.Permissions({
                beforeInitialize: true, // we check for dynamic fee
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

    function setFee(PoolId poolId, uint24 delta, int8 deltaSign) internal {
        (uint160 currentSqrtPriceX96, , , ) = poolManager.getSlot0(poolId);

        if (currentSqrtPriceX96 == poolToPrvSqrtPriceX96[poolId]) {
            return;
        }

        if (poolToPrvSqrtPriceX96[poolId] == 0) {
            poolToPrvSqrtPriceX96[poolId] = currentSqrtPriceX96;
            poolToCurrentFeeDelta[poolId] = 0;
            return;
        }

        if (deltaSign == 0) {
            // flow when oracle gives too old price
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
                sqrtPriceDelta,
                MULTIPLIER_DIVISOR
            );

            if (feeToChange >= uint256(BASE_FEE)) {
                poolToCurrentFeeDelta[poolId] = BASE_FEE;
            } else {
                // if poolToCurrentFeeDelta a uint256 is less than BASE_FEE a uint24, there should no value loss by downcasting
                poolToCurrentFeeDelta[poolId] = uint24(feeToChange);
            }
        } else {
            poolToCurrentFeeDeltaSign[poolId] = deltaSign;

            // fee = fee - c*delta, where c is a constant
            uint256 feeToChange = FullMath.mulDiv(
                MULTIPLIER,
                delta,
                MULTIPLIER_DIVISOR
            );

            if (feeToChange >= uint256(BASE_FEE)) {
                poolToCurrentFeeDelta[poolId] = BASE_FEE;
            } else {
                // if poolToCurrentFeeDelta a uint256 is less than BASE_FEE a uint24, there should no value loss by downcasting
                poolToCurrentFeeDelta[poolId] = uint24(feeToChange);
            }
        }

        poolToPrvSqrtPriceX96[poolId] = currentSqrtPriceX96;
    }

    function beforeSwap(
        address,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        bytes calldata hookData
    )
        external
        override
        onlyPoolManager
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        if (poolToLastUpdatedBN[key.toId()] < block.number) {
            poolToLastUpdatedBN[key.toId()] = block.number;
            (uint24 delta, int8 deltaSign) = getCexDexDelta(
                key.toId(),
                hookData
            );
            setFee(key.toId(), delta, deltaSign);
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

    function getCexDexDelta(
        PoolId poolId,
        bytes calldata data
    ) internal returns (uint24, int8) {
        (uint160 currentsqrtPriceXA96, , , ) = poolManager.getSlot0(poolId);
        uint256 currentPrice = FullMath.mulDiv(
            currentsqrtPriceXA96,
            currentsqrtPriceXA96,
            FullMath.mulDiv(FixedPoint96.Q96, FixedPoint96.Q96, EXPONENT)
        );
        uint48 currentTime = Time.timestamp();

        bytes[] memory priceUpdate = abi.decode(data, (bytes[]));
        PythStructs.Price memory price = getPriceFrom(priceUpdate);

        uint48 delay = uint48(price.publishTime) - currentTime;

        if (delay > TOLERABLE_DELAY_SEC) {
            return (0, 0);
        }

        uint256 cexPrice = uint256(uint64(price.price));

        uint256 delta = 0;
        int8 deltaSign = 0;
        if (cexPrice > currentPrice) {
            delta = cexPrice - currentPrice;
            deltaSign = 1;
        } else {
            delta = currentPrice - cexPrice;
            deltaSign = -1;
        }

        return (uint24(delta), deltaSign);
    }

    function getPriceFrom(
        bytes[] memory priceUpdate
    ) internal returns (PythStructs.Price memory) {
        uint fee = pyth.getUpdateFee(priceUpdate);
        pyth.updatePriceFeeds{value: fee}(priceUpdate);

        PythStructs.Price memory price = pyth.getPriceNoOlderThan(
            priceFeedId,
            60
        );
        return price;
    }

    /// @notice Fallback function to accept ETH transfers
    receive() external payable {}

    /// @notice Fallback function for when msg.data is not empty
    fallback() external payable {}
}
