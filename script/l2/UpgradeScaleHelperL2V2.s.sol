// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import 'forge-std/Script.sol';
import {console} from 'forge-std/console.sol';
import {InputScalingHelperL2V2} from 'src/l2-contracts/InputScalingHelperL2V2.sol';
import {Upgrades} from 'openzeppelin-foundry-upgrades/Upgrades.sol';
import {Options} from 'openzeppelin-foundry-upgrades/Options.sol';

contract UpgradeScaleHelperL2V2 is Script {
  function run() external {
    address proxySCAddress = 0xfdb60B1b5b3e8B4447BBCa53806DC023665Be8d1;

    uint256 priv = vm.envUint('PRIVATE_KEY');

    vm.startBroadcast(priv);

    Options memory opts;
    // where you upgrade from
    opts.referenceContract = 'InputScalingHelperL2V2.sol';

    // where you upgrade to
    string memory newContractName = 'InputScalingHelperL2V2.sol';

    Upgrades.upgradeProxy(proxySCAddress, newContractName, '', opts);

    vm.stopBroadcast();
  }
}
