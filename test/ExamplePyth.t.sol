// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {ExamplePyth} from "../src/ExamplePyth.sol";
import "forge-std/console2.sol";
import "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";

contract ExamplePythTest is Test {
    ExamplePyth examplePyth;
    PythStructs.Price public price;

    function setUp() public {
        examplePyth = new ExamplePyth(
            address(0x2880aB155794e7179c9eE2e38200202908C17B43)
        );
    }

    function test_exampleMethod() public {
        vm.deal(address(examplePyth), 10 ether);
        string[] memory cmds = new string[](4);
        cmds[0] = "npm";
        cmds[1] = "run";
        cmds[2] = "hermes";
        cmds[3] = "--silent";
        bytes memory res = vm.ffi(cmds);
        bytes[] memory updates = new bytes[](1);
        updates[0] = res;
        examplePyth.exampleMethod(updates);
        price = examplePyth.getPrice();
        console2.log(price.price);
        console2.log(price.expo);
        console2.log(price.conf);
        console2.log(price.publishTime);
        console2.log(block.timestamp);
    }
}
