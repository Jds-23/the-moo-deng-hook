// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library UnichainSepoliaDeployments {
    address public constant manager =
        0x7Cb22e8cfBdaCd1bC12Afe63ac0B561785d8a976;
    // address public constant manager =
    //     0xC81462Fec8B23319F288047f8A03A57682a35C1A; OG reverting for some reason
    address public constant token0 = 0x714A8B5821b8fBD7148C6A7f80A8239D5B9802B8;
    address public constant token1 = 0x75741A5766cb7A944E19609892812ED0A6990951;
    address public constant theHook =
        0x396Ed0A95D63A11C98Ca075f67A04f9C0772A080;
}
