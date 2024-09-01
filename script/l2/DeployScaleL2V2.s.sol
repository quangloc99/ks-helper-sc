// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import 'forge-std/Script.sol';
import {console} from 'forge-std/console.sol';
import {InputScalingHelperL2V2} from 'src/l2-contracts/InputScalingHelperL2V2.sol';

contract DeployScaleL2V2 is Script {
  function run() external {
    uint256 priv = vm.envUint('PRIVATE_KEY');

    vm.startBroadcast(priv);

    new InputScalingHelperL2V2();

    vm.stopBroadcast();
  }
}
