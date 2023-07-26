// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {JBDelegateMetadataHelper} from "../src/JBDelegateMetadataHelper.sol";

import "forge-std/Script.sol";

contract Deploy is Script {
    function run() external {
        vm.broadcast();
        JBDelegateMetadataHelper _helper = new JBDelegateMetadataHelper();

        console.log(address(_helper));
    }
}