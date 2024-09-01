// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import 'forge-std/Script.sol';
import {console} from 'forge-std/console.sol';
import {InputScalingHelperV2} from 'src/l1-contracts/InputScalingHelperV2.sol';
import {Upgrades} from 'openzeppelin-foundry-upgrades/Upgrades.sol';
import {Options} from 'openzeppelin-foundry-upgrades/Options.sol';

contract UpgradeScaleHelperL1V2 is Script {
  function run() external {
    address proxySCAddress = 0xdE55FB6223E8976DF774Ca27ECf38C7a2C772d64;

    uint256 priv = vm.envUint('PRIVATE_KEY');

    vm.startBroadcast(priv);

    Options memory opts;
    // where you upgrade from
    opts.referenceContract = 'InputScalingHelperV2.sol';

    // where you upgrade to
    string memory newContractName = 'InputScalingHelperV2.sol';

    Upgrades.upgradeProxy(proxySCAddress, newContractName, '', opts);

    vm.stopBroadcast();
  }
}
