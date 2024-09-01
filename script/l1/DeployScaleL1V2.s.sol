// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import 'forge-std/Script.sol';
import {console} from 'forge-std/console.sol';
import {InputScalingHelperV2} from 'src/l1-contracts/InputScalingHelperV2.sol';

contract DeployScaleL1V2 is Script {
  function run() external {
    uint256 priv = vm.envUint('PRIVATE_KEY');

    vm.startBroadcast(priv);

    new InputScalingHelperV2();

    vm.stopBroadcast();
  }
}
