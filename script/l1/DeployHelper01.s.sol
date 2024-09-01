// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import 'forge-std/Script.sol';
import {console} from 'forge-std/console.sol';
import {DexHelper01} from 'src/helpers/l1/DexHelper01.sol';

contract DeployHelper01 is Script {
  function run() external {
    uint256 priv = vm.envUint('PRIVATE_KEY');

    vm.startBroadcast(priv);

    new DexHelper01();

    vm.stopBroadcast();
  }
}
