"use strict";
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const viem_1 = require("viem");
const chains_1 = require("viem/chains");
const accounts_1 = require("viem/accounts");
const dotenv_1 = __importDefault(require("dotenv"));
const constants_1 = require("./constants");
dotenv_1.default.config();
const account = (0, accounts_1.privateKeyToAccount)(process.env.PRIVATE_KEY);
const client = (0, viem_1.createPublicClient)({
    chain: chains_1.unichainSepolia,
    transport: (0, viem_1.http)(),
});
const walletClient = (0, viem_1.createWalletClient)({
    account,
    chain: chains_1.unichainSepolia,
    transport: (0, viem_1.http)(),
});
modifyLiquidity();
function modifyLiquidity() {
    return __awaiter(this, void 0, void 0, function* () {
        const abis = (0, viem_1.parseAbi)([
            'function modifyLiquidity(PoolKey memory key, ModifyLiquidityParams memory params, bytes memory hookData)',
            'struct PoolKey { address currency0; address currency1; uint24 fee; int24 tickSpacing; address hooks; }',
            'struct ModifyLiquidityParams { int24 tickLower; int24 tickUpper; int256 liquidityDelta; bytes32 salt; }',
        ]);
        const calldata = (0, viem_1.encodeFunctionData)({
            abi: abis,
            functionName: 'modifyLiquidity',
            args: [
                constants_1.PoolKeyOfTheHook,
                { tickLower: -60, tickUpper: 60, liquidityDelta: (0, viem_1.parseEther)('100'), salt: '0x0000000000000000000000000000000000000000000000000000000000000000' },
                '0x0000000000000000000000000000000000000000000000000000000000000000',
            ],
        });
        console.log(calldata);
    });
}
