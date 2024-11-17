// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library UnichainSepoliaDeployments {
    address public constant manager =
        0xC81462Fec8B23319F288047f8A03A57682a35C1A;
    address public constant token0 = 0x714A8B5821b8fBD7148C6A7f80A8239D5B9802B8;
    address public constant token1 = 0x75741A5766cb7A944E19609892812ED0A6990951;
    address public constant pythContract =
        0x2880aB155794e7179c9eE2e38200202908C17B43;
    bytes32 public constant priceFeedId =
        bytes32(
            0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace
        );
}
