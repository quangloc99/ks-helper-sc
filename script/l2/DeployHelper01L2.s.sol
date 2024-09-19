// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import 'forge-std/Script.sol';
import {console} from 'forge-std/console.sol';
import {DexHelper01L2} from 'src/helpers/l2/DexHelper01L2.sol';

contract DeployHelper01L2 is Script {
  function run() external {
    uint256 priv = vm.envUint('PRIVATE_KEY');

    vm.startBroadcast(priv);

    new DexHelper01L2();

    vm.stopBroadcast();
  }
}
