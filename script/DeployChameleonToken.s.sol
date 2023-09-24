// SPDX-License-Identifier: MIT

pragma solidity ^0.8.21;

import {Script} from "../lib/forge-std/src/Script.sol";
import {ChameleonToken} from "../src/contracts/ChameleonToken.sol";

contract DeployChameleonToken is Script {
    function run() external returns (ChameleonToken) {
        vm.startBroadcast();
        ChameleonToken deploy = new ChameleonToken("Chameleon Token", "CT", 100000000000000000000000000);
        vm.stopBroadcast();
        return deploy;
    }
}