// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IAggregationExecutorOptimistic as IExecutorHelperL2} from
  '../interfaces/IAggregationExecutorOptimistic.sol';
import {IMetaAggregationRouterV2} from '../interfaces/IMetaAggregationRouterV2.sol';
import {ScalingDataL2Lib} from './ScalingDataL2Lib.sol';
import {ExecutorReader} from './ExecutorReader.sol';
import {CalldataWriter} from './CalldataWriter.sol';
import '@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol';
import '@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol';
import '@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol';

contract InputScalingHelperL2V2 is Initializable, OwnableUpgradeable, UUPSUpgradeable {
  using ExecutorReader for bytes;
  using ScalingDataL2Lib for bytes;

  uint256 private constant _PARTIAL_FILL = 0x01;
  uint256 private constant _REQUIRES_EXTRA_ETH = 0x02;
  uint256 private constant _SHOULD_CLAIM = 0x04;
  uint256 private constant _BURN_FROM_MSG_SENDER = 0x08;
  uint256 private constant _BURN_FROM_TX_ORIGIN = 0x10;
  uint256 private constant _SIMPLE_SWAP = 0x20;

  mapping(bytes4 => address) public helperOf;
  mapping(uint256 => bytes4) public funcSelectorOf;

  struct PositiveSlippageFeeData {
    uint256 partnerPSInfor;
    uint256 expectedReturnAmount;
  }

  function initialize() public initializer {
    __Ownable_init(msg.sender);
    __UUPSUpgradeable_init();
  }

  function _authorizeUpgrade(address) internal override onlyOwner {}

  function updateHelper(bytes4 funcSelector, uint256 index, address helper) external onlyOwner {
    helperOf[funcSelector] = helper;
    funcSelectorOf[index] = funcSelector;
  }

  function batchUpdateHelpers(
    bytes4[] memory funcSelectors,
    uint256[] memory indexes,
    address[] memory helpers
  ) external onlyOwner {
    require(
      funcSelectors.length == helpers.length && funcSelectors.length == indexes.length,
      'invalid length'
    );
    for (uint256 i; i < funcSelectors.length;) {
      helperOf[funcSelectors[i]] = helpers[i];
      funcSelectorOf[indexes[i]] = funcSelectors[i];

      unchecked {
        ++i;
      }
    }
  }

  function getScaledInputData(
    bytes calldata inputData,
    uint256 newAmount
  ) external view returns (bool isSuccess, bytes memory) {
    bytes4 selector = bytes4(inputData[:4]);
    bytes calldata dataToDecode = inputData[4:];

    if (selector == IMetaAggregationRouterV2.swap.selector) {
      IMetaAggregationRouterV2.SwapExecutionParams memory params =
        abi.decode(dataToDecode, (IMetaAggregationRouterV2.SwapExecutionParams));

      (isSuccess, params.desc, params.targetData) = _getScaledInputDataV2(
        params.desc, params.targetData, newAmount, _flagsChecked(params.desc.flags, _SIMPLE_SWAP)
      );

      if (!isSuccess) return (false, '');
      return (true, abi.encodeWithSelector(selector, params));
    } else if (selector == IMetaAggregationRouterV2.swapSimpleMode.selector) {
      (
        address callTarget,
        IMetaAggregationRouterV2.SwapDescriptionV2 memory desc,
        bytes memory targetData,
        bytes memory clientData
      ) = abi.decode(
        dataToDecode, (address, IMetaAggregationRouterV2.SwapDescriptionV2, bytes, bytes)
      );

      (isSuccess, desc, targetData) = _getScaledInputDataV2(desc, targetData, newAmount, true);
      if (!isSuccess) return (false, '');

      return (true, abi.encodeWithSelector(selector, callTarget, desc, targetData, clientData));
    } else {
      return (false, '');
    }
  }

  function _getScaledInputDataV2(
    IMetaAggregationRouterV2.SwapDescriptionV2 memory desc,
    bytes memory executorData,
    uint256 newAmount,
    bool isSimpleMode
  )
    internal
    view
    returns (
      bool isSuccess,
      IMetaAggregationRouterV2.SwapDescriptionV2 memory sDescription,
      bytes memory exCallData
    )
  {
    uint256 oldAmount = desc.amount;
    if (oldAmount == newAmount) {
      return (true, desc, executorData);
    }

    // simple mode swap
    if (isSimpleMode) {
      (isSuccess, exCallData) = _scaledSimpleSwapData(executorData, oldAmount, newAmount);
      if (!isSuccess) return (false, sDescription, '');
      return (isSuccess, _scaledSwapDescriptionV2(desc, oldAmount, newAmount), exCallData);
    }

    //normal mode swap
    (isSuccess, exCallData) = _scaledExecutorCallBytesData(executorData, oldAmount, newAmount);

    if (!isSuccess) return (false, sDescription, '');

    return (isSuccess, _scaledSwapDescriptionV2(desc, oldAmount, newAmount), exCallData);
  }

  /// @dev Scale the swap description
  function _scaledSwapDescriptionV2(
    IMetaAggregationRouterV2.SwapDescriptionV2 memory desc,
    uint256 oldAmount,
    uint256 newAmount
  ) internal pure returns (IMetaAggregationRouterV2.SwapDescriptionV2 memory) {
    desc.minReturnAmount = (desc.minReturnAmount * newAmount) / oldAmount;
    if (desc.minReturnAmount == 0) desc.minReturnAmount = 1;
    desc.amount = desc.amount * newAmount / oldAmount;

    uint256 nReceivers = desc.srcReceivers.length;
    for (uint256 i = 0; i < nReceivers;) {
      desc.srcAmounts[i] = (desc.srcAmounts[i] * newAmount) / oldAmount;
      unchecked {
        ++i;
      }
    }
    return desc;
  }

  /// @dev Scale the executorData in case swapSimpleMode
  function _scaledSimpleSwapData(
    bytes memory data,
    uint256 oldAmount,
    uint256 newAmount
  ) internal view returns (bool isSuccess, bytes memory) {
    IMetaAggregationRouterV2.SimpleSwapData memory simpleSwapData =
      abi.decode(data, (IMetaAggregationRouterV2.SimpleSwapData));
    uint256 nPools = simpleSwapData.firstPools.length;
    address tokenIn;

    for (uint256 i = 0; i < nPools;) {
      simpleSwapData.firstSwapAmounts[i] =
        (simpleSwapData.firstSwapAmounts[i] * newAmount) / oldAmount;

      IExecutorHelperL2.Swap[] memory dexData;

      (dexData, tokenIn) = simpleSwapData.swapDatas[i].readSwapSingleSequence();

      // only need to scale the first dex in each sequence
      if (dexData.length > 0) {
        (isSuccess, dexData[0]) = _scaleDexData(dexData[0], oldAmount, newAmount);
        if (!isSuccess) return (false, '');
      }

      simpleSwapData.swapDatas[i] =
        CalldataWriter._writeSwapSingleSequence(abi.encode(dexData), tokenIn);

      unchecked {
        ++i;
      }
    }

    (isSuccess, simpleSwapData.positiveSlippageData) =
      _scaledPositiveSlippageFeeData(simpleSwapData.positiveSlippageData, oldAmount, newAmount);

    if (!isSuccess) return (false, '');

    return (true, abi.encode(simpleSwapData));
  }

  /// @dev Scale the executorData in case normal swap
  function _scaledExecutorCallBytesData(
    bytes memory data,
    uint256 oldAmount,
    uint256 newAmount
  ) internal view returns (bool isSuccess, bytes memory) {
    IExecutorHelperL2.SwapExecutorDescription memory executorDesc =
      abi.decode(data.readSwapExecutorDescription(), (IExecutorHelperL2.SwapExecutorDescription));

    (isSuccess, executorDesc.positiveSlippageData) =
      _scaledPositiveSlippageFeeData(executorDesc.positiveSlippageData, oldAmount, newAmount);

    if (!isSuccess) return (false, '');

    uint256 nSequences = executorDesc.swapSequences.length;
    for (uint256 i = 0; i < nSequences;) {
      // only need to scale the first dex in each sequence
      IExecutorHelperL2.Swap memory swap = executorDesc.swapSequences[i][0];
      (isSuccess, executorDesc.swapSequences[i][0]) = _scaleDexData(swap, oldAmount, newAmount);
      if (!isSuccess) return (false, '');

      unchecked {
        ++i;
      }
    }

    return (true, CalldataWriter.writeSwapExecutorDescription(executorDesc));
  }

  function _scaledPositiveSlippageFeeData(
    bytes memory data,
    uint256 oldAmount,
    uint256 newAmount
  ) internal pure returns (bool isSuccess, bytes memory newData) {
    if (data.length > 32) {
      PositiveSlippageFeeData memory psData = abi.decode(data, (PositiveSlippageFeeData));
      uint256 left = uint256(psData.expectedReturnAmount >> 128);
      uint256 right = (uint256(uint128(psData.expectedReturnAmount)) * newAmount) / oldAmount;
      if (right > type(uint128).max) {
        return (false, '');
      }
      psData.expectedReturnAmount = right | (left << 128);
      data = abi.encode(psData);
    } else if (data.length == 32) {
      uint256 expectedReturnAmount = abi.decode(data, (uint256));
      uint256 left = uint256(expectedReturnAmount >> 128);
      uint256 right = (uint256(uint128(expectedReturnAmount)) * newAmount) / oldAmount;
      if (right > type(uint128).max) {
        return (false, '');
      }
      expectedReturnAmount = right | (left << 128);
      data = abi.encode(expectedReturnAmount);
    }

    return (true, data);
  }

  function _scaleDexData(
    IExecutorHelperL2.Swap memory swap,
    uint256 oldAmount,
    uint256 newAmount
  ) internal view returns (bool isSuccess, IExecutorHelperL2.Swap memory) {
    uint8 functionSelectorIndex = uint8(uint32(swap.functionSelector));

    bytes4 _funcSelector = funcSelectorOf[functionSelectorIndex];
    address _helperOf = helperOf[_funcSelector];

    if (_helperOf == address(0) || _funcSelector == bytes4(0)) return (false, swap);

    (bool success, bytes memory returnData) = _helperOf.staticcall(
      abi.encodeWithSelector(
        _funcSelector,
        0,
        abi.encode(swap.data, oldAmount, newAmount),
        0,
        address(0),
        false,
        address(0)
      )
    );

    if (!success) {
      return (false, swap);
    }
    swap.data = abi.decode(returnData, (bytes));

    return (true, swap);
  }

  function _flagsChecked(uint256 number, uint256 flag) internal pure returns (bool) {
    return number & flag != 0;
  }
}
