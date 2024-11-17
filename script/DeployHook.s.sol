// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {PoolManager} from "v4-core/PoolManager.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {UnichainSepoliaDeployments} from "utils/UnichainSepoliaDeployments.sol";
import {HookMiner} from "utils/HookMiner.sol";
import {TheHook} from "src/TheHook.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {LPFeeLibrary} from "v4-core/libraries/LPFeeLibrary.sol";
import "forge-std/console.sol";

contract DeployHook is Script {
    using PoolIdLibrary for PoolKey;

    PoolManager manager;

    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address deployerAddress = vm.addr(deployerPrivateKey);

    Currency token0;
    Currency token1;

    PoolKey key;

    function setUp() public {
        vm.startBroadcast(deployerPrivateKey);

        MockERC20 tokenA = MockERC20(UnichainSepoliaDeployments.token0);
        MockERC20 tokenB = MockERC20(UnichainSepoliaDeployments.token1);

        manager = PoolManager(UnichainSepoliaDeployments.manager);

        if (address(tokenA) > address(tokenB)) {
            (token0, token1) = (
                Currency.wrap(address(tokenB)),
                Currency.wrap(address(tokenA))
            );
        } else {
            (token0, token1) = (
                Currency.wrap(address(tokenA)),
                Currency.wrap(address(tokenB))
            );
        }

        // tokenA.approve(address(modifyLiquidityRouter), type(uint256).max);
        // tokenB.approve(address(modifyLiquidityRouter), type(uint256).max);
        // tokenA.approve(address(swapRouter), type(uint256).max);
        // tokenB.approve(address(swapRouter), type(uint256).max);

        // tokenA.mint(deployerAddress, 100 * 10 ** 18);
        // tokenB.mint(deployerAddress, 100 * 10 ** 18);

        // Set up the hook flags you wish to enable
        uint160 flags = uint160(
            Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_SWAP_FLAG
        );

        // Find an address + salt using HookMiner that meets our flags criteria
        address CREATE2_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
        (address hookAddress, bytes32 salt) = HookMiner.find(
            CREATE2_DEPLOYER,
            flags,
            type(TheHook).creationCode,
            abi.encode(address(manager))
        );

        TheHook hook = new TheHook{salt: salt}(manager);

        console.log("Hook Deployed at", address(hook));

        key = PoolKey({
            currency0: token0,
            currency1: token1,
            fee: LPFeeLibrary.DYNAMIC_FEE_FLAG,
            tickSpacing: 120,
            hooks: IHooks(hook)
        });

        console.log("Pool id");

        // the second argument here is SQRT_PRICE_1_1
        manager.initialize(key, 79228162514264337593543950336);
    }

    function run() external {}
}