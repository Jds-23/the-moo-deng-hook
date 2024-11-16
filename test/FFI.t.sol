// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";

// forge test --match-path test/FFI.t.sol --ffi -vvvv

contract FFITest is Test {
    function testFFI() public {
        string[] memory cmds = new string[](4);
        cmds[0] = "npm";
        cmds[1] = "run";
        cmds[2] = "hermes";
        cmds[3] = "--silent";
        bytes memory res = vm.ffi(cmds);
        console.logBytes(res);
    }
}
