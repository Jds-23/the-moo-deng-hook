"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.PoolKeyOfTheHook = void 0;
const addresses_1 = require("./addresses");
exports.PoolKeyOfTheHook = {
    currency0: addresses_1.addresses.token0,
    currency1: addresses_1.addresses.token1,
    fee: 8388608,
    tickSpacing: 60,
    hooks: addresses_1.addresses.theHook
};
