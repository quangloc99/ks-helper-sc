// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import 'forge-std/Script.sol';
import {console} from 'forge-std/console.sol';
import {DexHelper01L2} from 'src/helpers/l2/DexHelper01L2.sol';
import {InputScalingHelperL2V2} from 'src/l2-contracts/InputScalingHelperL2V2.sol';
import {IExecutorHelperL2} from 'src/interfaces/IExecutorHelperL2.sol';
import {Upgrades} from '@openzeppelin-foundry-upgrades/src/Upgrades.sol';

contract DeployScaleL2V2Full is Script {
  // @note: Please update this function to make sure this is latest data of supported helpers
  function _getFuncSelectorList() internal pure returns (bytes4[] memory funcSelectorList) {
    funcSelectorList = new bytes4[](53);
    funcSelectorList[0] = IExecutorHelperL2.executeUniswap.selector;
    funcSelectorList[1] = IExecutorHelperL2.executeKSClassic.selector;
    funcSelectorList[2] = IExecutorHelperL2.executeVelodrome.selector;
    funcSelectorList[3] = IExecutorHelperL2.executeFrax.selector;
    funcSelectorList[4] = IExecutorHelperL2.executeCamelot.selector;
    funcSelectorList[5] = IExecutorHelperL2.executeKyberLimitOrder.selector;
    funcSelectorList[6] = IExecutorHelperL2.executeRfq.selector;
    funcSelectorList[7] = IExecutorHelperL2.executeHashflow.selector;
    funcSelectorList[8] = IExecutorHelperL2.executeStableSwap.selector;
    funcSelectorList[9] = IExecutorHelperL2.executeCurve.selector;
    funcSelectorList[10] = IExecutorHelperL2.executeUniV3KSElastic.selector;
    funcSelectorList[11] = IExecutorHelperL2.executeBalV2.selector;
    funcSelectorList[12] = IExecutorHelperL2.executeDODO.selector;
    funcSelectorList[13] = IExecutorHelperL2.executeGMX.selector;
    funcSelectorList[14] = IExecutorHelperL2.executeSynthetix.selector;
    funcSelectorList[15] = IExecutorHelperL2.executeWrappedstETH.selector;
    funcSelectorList[16] = IExecutorHelperL2.executeStEth.selector;
    funcSelectorList[17] = IExecutorHelperL2.executePlatypus.selector;
    funcSelectorList[18] = IExecutorHelperL2.executePSM.selector;
    funcSelectorList[19] = IExecutorHelperL2.executeMaverick.selector;
    funcSelectorList[20] = IExecutorHelperL2.executeSyncSwap.selector;
    funcSelectorList[21] = IExecutorHelperL2.executeAlgebraV1.selector;
    funcSelectorList[22] = IExecutorHelperL2.executeBalancerBatch.selector;
    funcSelectorList[23] = IExecutorHelperL2.executeMantis.selector;
    funcSelectorList[24] = IExecutorHelperL2.executeWombat.selector;
    funcSelectorList[25] = IExecutorHelperL2.executeWooFiV2.selector;
    funcSelectorList[26] = IExecutorHelperL2.executeIziSwap.selector;
    funcSelectorList[27] = IExecutorHelperL2.executeTraderJoeV2.selector;
    funcSelectorList[28] = IExecutorHelperL2.executeKyberDSLO.selector;
    funcSelectorList[29] = IExecutorHelperL2.executeLevelFiV2.selector;
    funcSelectorList[30] = IExecutorHelperL2.executeGMXGLP.selector;
    funcSelectorList[31] = IExecutorHelperL2.executePancakeStableSwap.selector;
    funcSelectorList[32] = IExecutorHelperL2.executeVooi.selector;
    funcSelectorList[33] = IExecutorHelperL2.executeVelocoreV2.selector;
    funcSelectorList[34] = IExecutorHelperL2.executeSmardex.selector;
    funcSelectorList[35] = IExecutorHelperL2.executeSolidlyV2.selector;
    funcSelectorList[36] = IExecutorHelperL2.executeKokonut.selector;
    funcSelectorList[37] = IExecutorHelperL2.executeBalancerV1.selector;
    funcSelectorList[38] = IExecutorHelperL2.executeSwaapV2.selector;
    funcSelectorList[39] = IExecutorHelperL2.executeNomiswapStable.selector;
    funcSelectorList[40] = IExecutorHelperL2.executeArbswapStable.selector;
    funcSelectorList[41] = IExecutorHelperL2.executeBancorV3.selector;
    funcSelectorList[42] = IExecutorHelperL2.executeBancorV2.selector;
    funcSelectorList[43] = IExecutorHelperL2.executeAmbient.selector;
    funcSelectorList[44] = IExecutorHelperL2.executeNative.selector;
    funcSelectorList[45] = IExecutorHelperL2.executeLighterV2.selector;
    funcSelectorList[46] = IExecutorHelperL2.executeBebop.selector;
    funcSelectorList[47] = IExecutorHelperL2.executeMantleUsd.selector;
    funcSelectorList[48] = IExecutorHelperL2.executeMaiPSM.selector;
    funcSelectorList[49] = IExecutorHelperL2.executeKelp.selector;
    funcSelectorList[50] = IExecutorHelperL2.executeSymbioticLRT.selector;
    funcSelectorList[51] = IExecutorHelperL2.executeMaverickV2.selector;
    funcSelectorList[52] = IExecutorHelperL2.executeIntegral.selector;
  }

  function run() external {
    InputScalingHelperL2V2 scaleHelperSc;
    DexHelper01L2 dexHelper1;

    uint256 priv = vm.envUint('PRIVATE_KEY');

    vm.startBroadcast(priv);

    // deploy Dex helper and Scale helper
    address proxy = Upgrades.deployUUPSProxy(
      'InputScalingHelperL2V2.sol', abi.encodeCall(InputScalingHelperL2V2.initialize, ())
    );
    console.log('ScaleHelper Proxy deployed at:', address(proxy));

    dexHelper1 = new DexHelper01L2();
    console.log('DexHelper 1 deployed at:', address(dexHelper1));

    // setup helper mappings
    bytes4[] memory funcSelectorList = _getFuncSelectorList();
    uint256 listLength = funcSelectorList.length;
    address[] memory helperList = new address[](listLength);
    uint256[] memory indexList = new uint256[](listLength);
    for (uint16 i; i < listLength; i++) {
      indexList[i] = i;
      helperList[i] = address(dexHelper1);
    }

    InputScalingHelperL2V2 instance = InputScalingHelperL2V2(proxy);
    instance.batchUpdateHelpers(funcSelectorList, indexList, helperList);

    vm.stopBroadcast();
  }
}
