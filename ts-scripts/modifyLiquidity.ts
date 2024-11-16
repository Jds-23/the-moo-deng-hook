import { createPublicClient, createWalletClient, encodeFunctionData, http, parseAbi, parseEther } from 'viem';
import { unichainSepolia } from 'viem/chains';
import { privateKeyToAccount } from 'viem/accounts';
import dotenv from 'dotenv';
import { PoolKeyOfTheHook } from './constants';

dotenv.config();


const account = privateKeyToAccount(process.env.PRIVATE_KEY as `0x${string}`);

const client = createPublicClient({
    chain: unichainSepolia,
    transport: http(),
});

const walletClient = createWalletClient({
    account,
    chain: unichainSepolia,
    transport: http(),
});


modifyLiquidity();

async function modifyLiquidity() {

    const abis = parseAbi([
        'function modifyLiquidity(PoolKey memory key, ModifyLiquidityParams memory params, bytes memory hookData)',
        'struct PoolKey { address currency0; address currency1; uint24 fee; int24 tickSpacing; address hooks; }',
        'struct ModifyLiquidityParams { int24 tickLower; int24 tickUpper; int256 liquidityDelta; bytes32 salt; }',
    ]);
    const calldata = encodeFunctionData({
        abi: abis,
        functionName: 'modifyLiquidity',
        args: [
            PoolKeyOfTheHook,
            { tickLower: -60, tickUpper: 60, liquidityDelta: parseEther('100'), salt: '0x0000000000000000000000000000000000000000000000000000000000000000' },
            '0x0000000000000000000000000000000000000000000000000000000000000000',
        ],
    });

    console.log(calldata)
}

