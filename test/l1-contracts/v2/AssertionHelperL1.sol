// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Test, console} from 'forge-std/Test.sol';
import {IMetaAggregationRouterV2} from 'src/interfaces/IMetaAggregationRouterV2.sol';
import {IAggregationExecutor as IExecutorL1} from 'src/interfaces/IAggregationExecutor.sol';
import {InputScalingHelperV2} from 'src/l1-contracts/InputScalingHelperV2.sol';
import {IExecutorHelper, IExecutorHelperStruct} from 'src/interfaces/IExecutorHelper.sol';
import {BaseConfig} from './BaseConfig.sol';

contract AssertionHelperL1 is Test {
  address constant MOCK_ADDRESS = address(0);

  struct MockParams {
    address callTarget;
    address approveTarget;
    uint256 amount;
    uint256 minReturnAmount;
    address srcToken;
    address dstToken;
    address dstReceiver;
    address[] srcReceivers;
    uint256[] srcAmounts;
    uint8 recipientFlag;
    uint256 noSequences;
    IExecutorL1.Swap[][] swapSequences;
    address[] simpleSwapFirstPools;
    uint256[] simpleSwapFirstAmounts;
  }

  MockParams mockParams;

  function _assertScaledData(
    bytes memory rawData,
    bytes memory scaledRawData,
    uint256 oldAmount,
    uint256 newAmount,
    bool isSimpleMode
  ) internal {
    assertEq(rawData.length, scaledRawData.length, 'scaled data length not equal to original data');

    // remove first 4 bytes
    scaledRawData = this.excludeSighash(scaledRawData);

    IMetaAggregationRouterV2.SwapExecutionParams memory exec;
    bytes4 funcSelector;

    if (isSimpleMode) {
      (exec.callTarget, exec.desc, exec.targetData, exec.clientData) = abi.decode(
        scaledRawData, (address, IMetaAggregationRouterV2.SwapDescriptionV2, bytes, bytes)
      );

      IMetaAggregationRouterV2.SimpleSwapData memory simpleSwapData =
        abi.decode(exec.targetData, (IMetaAggregationRouterV2.SimpleSwapData));

      // check arrays length
      assertEq(simpleSwapData.firstSwapAmounts.length, simpleSwapData.swapDatas.length);
      assertEq(simpleSwapData.firstPools.length, simpleSwapData.swapDatas.length);

      // for each sequence
      for (uint256 i; i < simpleSwapData.firstPools.length; ++i) {
        // check first swap amounts scaled properly
        assertEq(simpleSwapData.firstSwapAmounts[i], mockParams.amount * newAmount / oldAmount);

        IExecutorL1.Swap[] memory swaps =
          abi.decode(simpleSwapData.swapDatas[i], (IExecutorL1.Swap[]));

        funcSelector = bytes4(uint32(uint256(swaps[0].selectorAndFlags) >> 252));

        // check scaled data for first dex
        _assertDexData(funcSelector, swaps[0].data, oldAmount, newAmount);
      }
    } else {
      // decode swap execution params should not fail
      exec = abi.decode(scaledRawData, (IMetaAggregationRouterV2.SwapExecutionParams));

      // decode executor data
      IExecutorL1.SwapExecutorDescription memory executorDesc =
        abi.decode(exec.targetData, (IExecutorL1.SwapExecutorDescription));

      // check scaled data for each first dex
      for (uint256 i; i < executorDesc.swapSequences.length; ++i) {
        funcSelector = bytes4(executorDesc.swapSequences[i][0].selectorAndFlags);

        _assertDexData(funcSelector, executorDesc.swapSequences[i][0].data, oldAmount, newAmount);
      }
    }

    for (uint256 i; i < exec.desc.srcAmounts.length; ++i) {
      assertEq(
        exec.desc.srcAmounts[i],
        mockParams.amount * newAmount / oldAmount,
        'desc.srcAmounts scaled improperly'
      );
    }

    // check description amount scaled properly
    assertEq(
      exec.desc.amount,
      mockParams.amount * newAmount / oldAmount,
      'router desc amount not scaled properly'
    );

    uint256 expectedMinReturnAmount = mockParams.minReturnAmount * newAmount / oldAmount;
    if (expectedMinReturnAmount == 0) expectedMinReturnAmount = 1;

    assertEq(
      exec.desc.minReturnAmount,
      expectedMinReturnAmount,
      'router desc min return amount not scaled properly'
    );
  }

  function _assertDexData(
    bytes4 funcSelector,
    bytes memory dexData,
    uint256 oldAmount,
    uint256 newAmount
  ) internal {
    function (bytes memory,uint256,uint256) internal fn;

    if (
      funcSelector == IExecutorHelper.executeUniswap.selector
        || funcSelector == IExecutorHelper.executeKSClassic.selector
        || funcSelector == IExecutorHelper.executeVelodrome.selector
        || funcSelector == IExecutorHelper.executeFrax.selector
        || funcSelector == IExecutorHelper.executeCamelot.selector
    ) {
      fn = assertUniData;
    } else if (
      funcSelector == IExecutorHelper.executeMantis.selector
        || funcSelector == IExecutorHelper.executeWombat.selector
        || funcSelector == IExecutorHelper.executeWooFiV2.selector
        || funcSelector == IExecutorHelper.executeSmardex.selector
        || funcSelector == IExecutorHelper.executeSolidlyV2.selector
        || funcSelector == IExecutorHelper.executeNomiswapStable.selector
        || funcSelector == IExecutorHelper.executeBancorV3.selector
    ) {
      fn = assertMantisData;
    } else if (
      funcSelector == IExecutorHelper.executeCurve.selector
        || funcSelector == IExecutorHelper.executePancakeStableSwap.selector
    ) {
      fn = assertCurveData;
    } else if (
      funcSelector == IExecutorHelper.executeOriginETH.selector
        || funcSelector == IExecutorHelper.executePrimeETH.selector
    ) {
      fn = assertOriginETHData;
    } else if (
      funcSelector == IExecutorHelper.executeFrxETH.selector
        || funcSelector == IExecutorHelper.executeMaiPSM.selector
    ) {
      fn = assertFrxETHData;
    } else if (funcSelector == IExecutorHelper.executeStableSwap.selector) {
      fn = assertStableSwapData;
    } else if (funcSelector == IExecutorHelper.executeGMX.selector) {
      fn = assertGMXData;
    } else if (funcSelector == IExecutorHelper.executeUniV3KSElastic.selector) {
      fn = assertUniv3Data;
    } else if (funcSelector == IExecutorHelper.executeRfq.selector) {
      fn = assertRfqData;
    } else if (funcSelector == IExecutorHelper.executeBalV2.selector) {
      fn = assertBalv2Data;
    } else if (funcSelector == IExecutorHelper.executeDODO.selector) {
      fn = assertDodoData;
    } else if (funcSelector == IExecutorHelper.executeSynthetix.selector) {
      fn = assertSynthetixData;
    } else if (funcSelector == IExecutorHelper.executePSM.selector) {
      fn = assertPSMData;
    } else if (funcSelector == IExecutorHelper.executeWrappedstETH.selector) {
      fn = assertWstethData;
    } else if (
      funcSelector == IExecutorHelper.executeStEth.selector
        || funcSelector == IExecutorHelper.executeWBETH.selector
        || funcSelector == IExecutorHelper.executeMantleETH.selector
        || funcSelector == IExecutorHelper.executeEtherFieETH.selector
        || funcSelector == IExecutorHelper.executeRswETH.selector
        || funcSelector == IExecutorHelper.executeBedrockUniETH.selector
        || funcSelector == IExecutorHelper.executeSwellETH.selector
    ) {
      fn = assertStethData;
    } else if (funcSelector == IExecutorHelper.executePlatypus.selector) {
      fn = assertPlatypusData;
    } else if (funcSelector == IExecutorHelper.executeMaverick.selector) {
      fn = assertMaverickData;
    } else if (funcSelector == IExecutorHelper.executeSyncSwap.selector) {
      fn = assertSyncSwapData;
    } else if (funcSelector == IExecutorHelper.executeAlgebraV1.selector) {
      fn = assertAlgebraV1Data;
    } else if (funcSelector == IExecutorHelper.executeBalancerBatch.selector) {
      fn = assertBalancerBatchData;
    } else if (funcSelector == IExecutorHelper.executeIziSwap.selector) {
      fn = assertIziSwapData;
    } else if (funcSelector == IExecutorHelper.executeTraderJoeV2.selector) {
      fn = assertTraderJoeV2Data;
    } else if (funcSelector == IExecutorHelper.executeLevelFiV2.selector) {
      fn = assertLevelFiV2Data;
    } else if (funcSelector == IExecutorHelper.executeGMXGLP.selector) {
      fn = assertGMXGLPData;
    } else if (funcSelector == IExecutorHelper.executeVooi.selector) {
      fn = assertVooiData;
    } else if (funcSelector == IExecutorHelper.executeVelocoreV2.selector) {
      fn = assertVelocoreV2Data;
    } else if (funcSelector == IExecutorHelper.executeMaticMigrate.selector) {
      fn = assertMaticMigrateData;
    } else if (funcSelector == IExecutorHelper.executeKokonut.selector) {
      fn = assertKokonutData;
    } else if (funcSelector == IExecutorHelper.executeBalancerV1.selector) {
      fn = assertBalancerV1Data;
    } else if (funcSelector == IExecutorHelper.executeArbswapStable.selector) {
      fn = assertArbswapStableData;
    } else if (funcSelector == IExecutorHelper.executeBancorV2.selector) {
      fn = assertBancorV2Data;
    } else if (funcSelector == IExecutorHelper.executeAmbient.selector) {
      fn = assertAmbientData;
    } else if (funcSelector == IExecutorHelper.executeUniV1.selector) {
      fn = assertUniV1Data;
    } else if (funcSelector == IExecutorHelper.executeLighterV2.selector) {
      fn = assertLighterV2Data;
    } else if (funcSelector == IExecutorHelper.executeEtherFiWeETH.selector) {
      fn = assertEtherFiWeETHData;
    } else if (funcSelector == IExecutorHelper.executeKelp.selector) {
      fn = assertKelpData;
    } else if (funcSelector == IExecutorHelper.executeEthenaSusde.selector) {
      fn = assertEthenaSusdeData;
    } else if (funcSelector == IExecutorHelper.executeRocketPool.selector) {
      fn = assertRocketPoolData;
    } else if (funcSelector == IExecutorHelper.executeMakersDAI.selector) {
      fn = assertMakersDAIData;
    } else if (funcSelector == IExecutorHelper.executeRenzo.selector) {
      fn = assertRenzoData;
    } else if (funcSelector == IExecutorHelper.executeSfrxETH.selector) {
      fn = assertSfrxETHData;
    } else if (funcSelector == IExecutorHelper.executeSfrxETHConvertor.selector) {
      fn = assertSfrxETHConvertorData;
    } else if (funcSelector == IExecutorHelper.executeStaderETHx.selector) {
      fn = assertStaderETHxData;
    } else if (
      funcSelector == IExecutorHelper.executeMantleUsd.selector
        || funcSelector == IExecutorHelper.executeUsd0PP.selector
    ) {
      fn = assertMantleUsdData;
    } else if (funcSelector == IExecutorHelper.executePufferFinance.selector) {
      fn = assertPufferFinanceData;
    } else if (funcSelector == IExecutorHelper.executeHashflow.selector) {
      fn = assertHashflowData;
    } else if (funcSelector == IExecutorHelper.executeNative.selector) {
      fn = assertNativeData;
    } else if (funcSelector == IExecutorHelper.executeKyberLimitOrder.selector) {
      fn = assertKyberLOData;
    } else if (funcSelector == IExecutorHelper.executeKyberDSLO.selector) {
      fn = assertKyberDSLOData;
    } else if (
      funcSelector == IExecutorHelper.executeMaverickV2.selector
        || funcSelector == IExecutorHelper.executeIntegral.selector
    ) {
      fn = assertMaverickV2Data;
    } else {
      // @note change this
      console.log('NOT SUPPORTED');
      fn = assertNothing;
      // do nothing, since we need to check revert condition from InputScalingHelperL2 contract
    }

    fn(dexData, newAmount, oldAmount);
  }

  function assertNothing(bytes memory dexData, uint256 newAmount, uint256 oldAmount) internal {}

  function assertUniData(bytes memory dexData, uint256 newAmount, uint256 oldAmount) internal {
    IExecutorHelperStruct.UniSwap memory dexStructData =
      abi.decode(dexData, (IExecutorHelperStruct.UniSwap));
    assertEq(dexStructData.collectAmount, mockParams.amount * newAmount / oldAmount);
  }

  function assertMantisData(bytes memory dexData, uint256 newAmount, uint256 oldAmount) internal {
    IExecutorHelperStruct.Mantis memory dexStructData =
      abi.decode(dexData, (IExecutorHelperStruct.Mantis));
    assertEq(dexStructData.amount, mockParams.amount * newAmount / oldAmount);
  }

  function assertCurveData(bytes memory dexData, uint256 newAmount, uint256 oldAmount) internal {
    IExecutorHelperStruct.CurveSwap memory dexStructData =
      abi.decode(dexData, (IExecutorHelperStruct.CurveSwap));
    assertEq(dexStructData.dx, mockParams.amount * newAmount / oldAmount);
  }

  function assertOriginETHData(bytes memory dexData, uint256 newAmount, uint256 oldAmount) internal {
    IExecutorHelperStruct.OriginETH memory dexStructData =
      abi.decode(dexData, (IExecutorHelperStruct.OriginETH));
    assertEq(dexStructData.amount, mockParams.amount * newAmount / oldAmount);
  }

  function assertFrxETHData(bytes memory dexData, uint256 newAmount, uint256 oldAmount) internal {
    IExecutorHelperStruct.FrxETH memory dexStructData =
      abi.decode(dexData, (IExecutorHelperStruct.FrxETH));
    assertEq(dexStructData.amount, mockParams.amount * newAmount / oldAmount);
  }

  function assertStableSwapData(
    bytes memory dexData,
    uint256 newAmount,
    uint256 oldAmount
  ) internal {
    IExecutorHelperStruct.StableSwap memory dexStructData =
      abi.decode(dexData, (IExecutorHelperStruct.StableSwap));
    assertEq(dexStructData.dx, mockParams.amount * newAmount / oldAmount);
  }

  function assertGMXData(bytes memory dexData, uint256 newAmount, uint256 oldAmount) internal {
    IExecutorHelperStruct.GMX memory dexStructData =
      abi.decode(dexData, (IExecutorHelperStruct.GMX));
    assertEq(dexStructData.amount, mockParams.amount * newAmount / oldAmount);
  }

  function assertUniv3Data(bytes memory dexData, uint256 newAmount, uint256 oldAmount) internal {
    IExecutorHelperStruct.UniswapV3KSElastic memory dexStructData =
      abi.decode(dexData, (IExecutorHelperStruct.UniswapV3KSElastic));
    assertEq(dexStructData.swapAmount, mockParams.amount * newAmount / oldAmount);
  }

  function assertRfqData(bytes memory dexData, uint256 newAmount, uint256 oldAmount) internal {
    IExecutorHelperStruct.KyberRFQ memory dexStructData =
      abi.decode(dexData, (IExecutorHelperStruct.KyberRFQ));
    assertEq(dexStructData.amount, mockParams.amount * newAmount / oldAmount);
  }

  function assertBalv2Data(bytes memory dexData, uint256 newAmount, uint256 oldAmount) internal {
    IExecutorHelperStruct.BalancerV2 memory dexStructData =
      abi.decode(dexData, (IExecutorHelperStruct.BalancerV2));
    assertEq(dexStructData.amount, mockParams.amount * newAmount / oldAmount);
  }

  function assertDodoData(bytes memory dexData, uint256 newAmount, uint256 oldAmount) internal {
    IExecutorHelperStruct.DODO memory dexStructData =
      abi.decode(dexData, (IExecutorHelperStruct.DODO));
    assertEq(dexStructData.amount, mockParams.amount * newAmount / oldAmount);
  }

  function assertSynthetixData(bytes memory dexData, uint256 newAmount, uint256 oldAmount) internal {
    IExecutorHelperStruct.Synthetix memory dexStructData =
      abi.decode(dexData, (IExecutorHelperStruct.Synthetix));
    assertEq(dexStructData.sourceAmount, mockParams.amount * newAmount / oldAmount);
  }

  function assertPSMData(bytes memory dexData, uint256 newAmount, uint256 oldAmount) internal {
    IExecutorHelperStruct.PSM memory dexStructData =
      abi.decode(dexData, (IExecutorHelperStruct.PSM));
    assertEq(dexStructData.amountIn, mockParams.amount * newAmount / oldAmount);
  }

  function assertWstethData(bytes memory dexData, uint256 newAmount, uint256 oldAmount) internal {
    IExecutorHelperStruct.WSTETH memory dexStructData =
      abi.decode(dexData, (IExecutorHelperStruct.WSTETH));
    assertEq(dexStructData.amount, mockParams.amount * newAmount / oldAmount);
  }

  function assertStethData(bytes memory dexData, uint256 newAmount, uint256 oldAmount) internal {
    assertEq(abi.decode(dexData, (uint256)), mockParams.amount * newAmount / oldAmount);
  }

  function assertPlatypusData(bytes memory dexData, uint256 newAmount, uint256 oldAmount) internal {
    IExecutorHelperStruct.Platypus memory dexStructData =
      abi.decode(dexData, (IExecutorHelperStruct.Platypus));
    assertEq(dexStructData.collectAmount, mockParams.amount * newAmount / oldAmount);
  }

  function assertMaverickData(bytes memory dexData, uint256 newAmount, uint256 oldAmount) internal {
    IExecutorHelperStruct.Maverick memory dexStructData =
      abi.decode(dexData, (IExecutorHelperStruct.Maverick));
    assertEq(dexStructData.swapAmount, mockParams.amount * newAmount / oldAmount);
  }

  function assertSyncSwapData(bytes memory dexData, uint256 newAmount, uint256 oldAmount) internal {
    IExecutorHelperStruct.SyncSwap memory dexStructData =
      abi.decode(dexData, (IExecutorHelperStruct.SyncSwap));
    assertEq(dexStructData.collectAmount, mockParams.amount * newAmount / oldAmount);
  }

  function assertAlgebraV1Data(bytes memory dexData, uint256 newAmount, uint256 oldAmount) internal {
    IExecutorHelperStruct.AlgebraV1 memory dexStructData =
      abi.decode(dexData, (IExecutorHelperStruct.AlgebraV1));
    assertEq(dexStructData.swapAmount, mockParams.amount * newAmount / oldAmount);
  }

  function assertBalancerBatchData(
    bytes memory dexData,
    uint256 newAmount,
    uint256 oldAmount
  ) internal {
    IExecutorHelperStruct.BalancerBatch memory dexStructData =
      abi.decode(dexData, (IExecutorHelperStruct.BalancerBatch));
    assertEq(dexStructData.amountIn, mockParams.amount * newAmount / oldAmount);
  }

  function assertIziSwapData(bytes memory dexData, uint256 newAmount, uint256 oldAmount) internal {
    IExecutorHelperStruct.IziSwap memory dexStructData =
      abi.decode(dexData, (IExecutorHelperStruct.IziSwap));
    assertEq(dexStructData.swapAmount, mockParams.amount * newAmount / oldAmount);
  }

  function assertTraderJoeV2Data(
    bytes memory dexData,
    uint256 newAmount,
    uint256 oldAmount
  ) internal {
    IExecutorHelperStruct.TraderJoeV2 memory dexStructData =
      abi.decode(dexData, (IExecutorHelperStruct.TraderJoeV2));
    assertEq(dexStructData.collectAmount, mockParams.amount * newAmount / oldAmount);
  }

  function assertLevelFiV2Data(bytes memory dexData, uint256 newAmount, uint256 oldAmount) internal {
    IExecutorHelperStruct.LevelFiV2 memory dexStructData =
      abi.decode(dexData, (IExecutorHelperStruct.LevelFiV2));
    assertEq(dexStructData.amountIn, mockParams.amount * newAmount / oldAmount);
  }

  function assertGMXGLPData(bytes memory dexData, uint256 newAmount, uint256 oldAmount) internal {
    IExecutorHelperStruct.GMXGLP memory dexStructData =
      abi.decode(dexData, (IExecutorHelperStruct.GMXGLP));
    assertEq(dexStructData.swapAmount, mockParams.amount * newAmount / oldAmount);
  }

  function assertVooiData(bytes memory dexData, uint256 newAmount, uint256 oldAmount) internal {
    IExecutorHelperStruct.Vooi memory dexStructData =
      abi.decode(dexData, (IExecutorHelperStruct.Vooi));
    assertEq(dexStructData.fromAmount, mockParams.amount * newAmount / oldAmount);
  }

  function assertVelocoreV2Data(
    bytes memory dexData,
    uint256 newAmount,
    uint256 oldAmount
  ) internal {
    IExecutorHelperStruct.VelocoreV2 memory dexStructData =
      abi.decode(dexData, (IExecutorHelperStruct.VelocoreV2));
    assertEq(dexStructData.amount, mockParams.amount * newAmount / oldAmount);
  }

  function assertMaticMigrateData(
    bytes memory dexData,
    uint256 newAmount,
    uint256 oldAmount
  ) internal {
    IExecutorHelperStruct.MaticMigrate memory dexStructData =
      abi.decode(dexData, (IExecutorHelperStruct.MaticMigrate));
    assertEq(dexStructData.amount, mockParams.amount * newAmount / oldAmount);
  }

  function assertKokonutData(bytes memory dexData, uint256 newAmount, uint256 oldAmount) internal {
    IExecutorHelperStruct.Kokonut memory dexStructData =
      abi.decode(dexData, (IExecutorHelperStruct.Kokonut));
    assertEq(dexStructData.dx, mockParams.amount * newAmount / oldAmount);
  }

  function assertBalancerV1Data(
    bytes memory dexData,
    uint256 newAmount,
    uint256 oldAmount
  ) internal {
    IExecutorHelperStruct.BalancerV1 memory dexStructData =
      abi.decode(dexData, (IExecutorHelperStruct.BalancerV1));
    assertEq(dexStructData.amount, mockParams.amount * newAmount / oldAmount);
  }

  function assertArbswapStableData(
    bytes memory dexData,
    uint256 newAmount,
    uint256 oldAmount
  ) internal {
    IExecutorHelperStruct.ArbswapStable memory dexStructData =
      abi.decode(dexData, (IExecutorHelperStruct.ArbswapStable));
    assertEq(dexStructData.dx, mockParams.amount * newAmount / oldAmount);
  }

  function assertBancorV2Data(bytes memory dexData, uint256 newAmount, uint256 oldAmount) internal {
    IExecutorHelperStruct.BancorV2 memory dexStructData =
      abi.decode(dexData, (IExecutorHelperStruct.BancorV2));
    assertEq(dexStructData.amount, mockParams.amount * newAmount / oldAmount);
  }

  function assertAmbientData(bytes memory dexData, uint256 newAmount, uint256 oldAmount) internal {
    IExecutorHelperStruct.Ambient memory dexStructData =
      abi.decode(dexData, (IExecutorHelperStruct.Ambient));
    assertEq(dexStructData.qty, mockParams.amount * newAmount / oldAmount);
  }

  function assertUniV1Data(bytes memory dexData, uint256 newAmount, uint256 oldAmount) internal {
    IExecutorHelperStruct.UniV1 memory dexStructData =
      abi.decode(dexData, (IExecutorHelperStruct.UniV1));
    assertEq(dexStructData.amount, mockParams.amount * newAmount / oldAmount);
  }

  function assertLighterV2Data(bytes memory dexData, uint256 newAmount, uint256 oldAmount) internal {
    IExecutorHelperStruct.LighterV2 memory dexStructData =
      abi.decode(dexData, (IExecutorHelperStruct.LighterV2));
    assertEq(dexStructData.amount, mockParams.amount * newAmount / oldAmount);
  }

  function assertEtherFiWeETHData(
    bytes memory dexData,
    uint256 newAmount,
    uint256 oldAmount
  ) internal {
    IExecutorHelperStruct.EtherFiWeETH memory dexStructData =
      abi.decode(dexData, (IExecutorHelperStruct.EtherFiWeETH));
    assertEq(dexStructData.amount, mockParams.amount * newAmount / oldAmount);
  }

  function assertKelpData(bytes memory dexData, uint256 newAmount, uint256 oldAmount) internal {
    IExecutorHelperStruct.Kelp memory dexStructData =
      abi.decode(dexData, (IExecutorHelperStruct.Kelp));
    assertEq(dexStructData.amount, mockParams.amount * newAmount / oldAmount);
  }

  function assertEthenaSusdeData(
    bytes memory dexData,
    uint256 newAmount,
    uint256 oldAmount
  ) internal {
    IExecutorHelperStruct.EthenaSusde memory dexStructData =
      abi.decode(dexData, (IExecutorHelperStruct.EthenaSusde));
    assertEq(dexStructData.amount, mockParams.amount * newAmount / oldAmount);
  }

  function assertRocketPoolData(
    bytes memory dexData,
    uint256 newAmount,
    uint256 oldAmount
  ) internal {
    IExecutorHelperStruct.RocketPool memory dexStructData =
      abi.decode(dexData, (IExecutorHelperStruct.RocketPool));

    uint256 amountData = uint256(uint128(dexStructData.isDepositAndAmount));
    assertEq(amountData, mockParams.amount * newAmount / oldAmount);
  }

  function assertMakersDAIData(bytes memory dexData, uint256 newAmount, uint256 oldAmount) internal {
    IExecutorHelperStruct.MakersDAI memory dexStructData =
      abi.decode(dexData, (IExecutorHelperStruct.MakersDAI));

    uint256 amountData = uint256(uint128(dexStructData.isRedeemAndAmount));

    assertEq(amountData, mockParams.amount * newAmount / oldAmount);
  }

  function assertRenzoData(bytes memory dexData, uint256 newAmount, uint256 oldAmount) internal {
    IExecutorHelperStruct.Renzo memory dexStructData =
      abi.decode(dexData, (IExecutorHelperStruct.Renzo));
    assertEq(dexStructData.amount, mockParams.amount * newAmount / oldAmount);
  }

  function assertSfrxETHData(bytes memory dexData, uint256 newAmount, uint256 oldAmount) internal {
    IExecutorHelperStruct.SfrxETH memory dexStructData =
      abi.decode(dexData, (IExecutorHelperStruct.SfrxETH));
    assertEq(dexStructData.amount, mockParams.amount * newAmount / oldAmount);
  }

  function assertSfrxETHConvertorData(
    bytes memory dexData,
    uint256 newAmount,
    uint256 oldAmount
  ) internal {
    IExecutorHelperStruct.SfrxETHConvertor memory dexStructData =
      abi.decode(dexData, (IExecutorHelperStruct.SfrxETHConvertor));
    uint256 amountData = uint256(uint128(dexStructData.isDepositAndAmount));

    assertEq(amountData, mockParams.amount * newAmount / oldAmount);
  }

  function assertStaderETHxData(
    bytes memory dexData,
    uint256 newAmount,
    uint256 oldAmount
  ) internal {
    IExecutorHelperStruct.StaderETHx memory dexStructData =
      abi.decode(dexData, (IExecutorHelperStruct.StaderETHx));
    assertEq(dexStructData.amount, mockParams.amount * newAmount / oldAmount);
  }

  function assertMantleUsdData(bytes memory dexData, uint256 newAmount, uint256 oldAmount) internal {
    uint256 amountDecode = abi.decode(dexData, (uint256));
    uint256 amountData = uint256(uint128(amountDecode));
    assertEq(amountData, mockParams.amount * newAmount / oldAmount);
  }

  function assertPufferFinanceData(
    bytes memory dexData,
    uint256 newAmount,
    uint256 oldAmount
  ) internal {
    IExecutorHelperStruct.PufferFinance memory dexStructData =
      abi.decode(dexData, (IExecutorHelperStruct.PufferFinance));
    assertEq(dexStructData.permit.amount, mockParams.amount * newAmount / oldAmount);
  }

  function assertHashflowData(bytes memory dexData, uint256 newAmount, uint256 oldAmount) internal {
    IExecutorHelperStruct.Hashflow memory dexStructData =
      abi.decode(dexData, (IExecutorHelperStruct.Hashflow));
    assertEq(
      dexStructData.quote.effectiveBaseTokenAmount, mockParams.amount * newAmount / oldAmount
    );
  }

  function assertNativeData(bytes memory dexData, uint256 newAmount, uint256 oldAmount) internal {
    IExecutorHelperStruct.Native memory dexStructData =
      abi.decode(dexData, (IExecutorHelperStruct.Native));
    assertEq(dexStructData.amount, mockParams.amount * newAmount / oldAmount);
  }

  function assertKyberLOData(bytes memory dexData, uint256 newAmount, uint256 oldAmount) internal {
    IExecutorHelperStruct.KyberLimitOrder memory dexStructData =
      abi.decode(dexData, (IExecutorHelperStruct.KyberLimitOrder));
    assertEq(dexStructData.params.takingAmount, mockParams.amount * newAmount / oldAmount);
  }

  function assertKyberDSLOData(bytes memory dexData, uint256 newAmount, uint256 oldAmount) internal {
    IExecutorHelperStruct.KyberDSLO memory dexStructData =
      abi.decode(dexData, (IExecutorHelperStruct.KyberDSLO));
    assertEq(dexStructData.params.takingAmount, mockParams.amount * newAmount / oldAmount);
  }

  function assertSymbioticLRTData(
    bytes memory dexData,
    uint256 newAmount,
    uint256 oldAmount
  ) internal {
    IExecutorHelperStruct.SymbioticLRT memory dexStructData =
      abi.decode(dexData, (IExecutorHelperStruct.SymbioticLRT));
    assertEq(dexStructData.amount, mockParams.amount * newAmount / oldAmount);
  }

  function assertMaverickV2Data(
    bytes memory dexData,
    uint256 newAmount,
    uint256 oldAmount
  ) internal {
    IExecutorHelperStruct.MaverickV2 memory dexStructData =
      abi.decode(dexData, (IExecutorHelperStruct.MaverickV2));
    assertEq(dexStructData.collectAmount, mockParams.amount * newAmount / oldAmount);
  }

  function excludeSighash(bytes calldata rawData) external pure returns (bytes memory) {
    return rawData[4:];
  }
}
