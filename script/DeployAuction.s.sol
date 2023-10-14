// SPDX-License-Identifier: MIT

pragma solidity ^0.8.21;

import {Script} from "../lib/forge-std/src/Script.sol";
import {Auction} from "../src/contracts/Auction.sol";

contract DeployAuction is Script {
    function run() external returns (Auction) {
        vm.startBroadcast();
        Auction deploy = new Auction();
        vm.stopBroadcast();
        return deploy;
    }
}
