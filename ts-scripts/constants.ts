import { addresses } from "./addresses";

export const PoolKeyOfTheHook: {
    currency0: `0x${string}`;
    currency1: `0x${string}`;
    fee: number;
    tickSpacing: number;
    hooks: `0x${string}`;
} = {
    currency0: addresses.token0,
    currency1: addresses.token1,
    fee: 8388608,
    tickSpacing: 60,
    hooks: addresses.theHook
}