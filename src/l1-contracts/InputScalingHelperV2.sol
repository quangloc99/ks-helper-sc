// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import '@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol';
import '@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol';
import '@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol';

import {IMetaAggregationRouterV2} from 'src/interfaces/IMetaAggregationRouterV2.sol';

import {RevertReasonParser} from 'src/libraries/RevertReasonParser.sol';

contract InputScalingHelperV2 is Initializable, OwnableUpgradeable, UUPSUpgradeable {
  uint256 private constant _PARTIAL_FILL = 0x01;
  uint256 private constant _REQUIRES_EXTRA_ETH = 0x02;
  uint256 private constant _SHOULD_CLAIM = 0x04;
  uint256 private constant _BURN_FROM_MSG_SENDER = 0x08;
  uint256 private constant _BURN_FROM_TX_ORIGIN = 0x10;
  uint256 private constant _SIMPLE_SWAP = 0x20;

  mapping(bytes4 => address) public helperOf;

  // fee data in case taking in dest token
  struct PositiveSlippageFeeData {
    uint256 partnerPSInfor; // [partnerReceiver (160 bit) + partnerPercent(80bits) + partnerFeeMode(16 bits)]
    uint256 amounts; // [minimumPSAmount (128 bits) + expectedReturnAmount (128 bits)]
    address feeSharingAddress;
  }

  struct Swap {
    bytes data;
    bytes32 selectorAndFlags; // [selector (32 bits) + flags (224 bits)]; selector is 4 most significant bytes; flags are stored in 4 least significant bytes.
  }

  struct SimpleSwapData {
    address[] firstPools;
    uint256[] firstSwapAmounts;
    bytes[] swapDatas;
    uint256 deadline;
    bytes positiveSlippageData;
  }

  struct SwapExecutorDescription {
    Swap[][] swapSequences;
    address tokenIn;
    address tokenOut;
    address to;
    uint256 deadline;
    bytes positiveSlippageData;
  }

  function initialize() public initializer {
    __Ownable_init(msg.sender);
    __UUPSUpgradeable_init();
  }

  function _authorizeUpgrade(address) internal override onlyOwner {}

  function updateHelper(bytes4 funcSelector, address helper) external onlyOwner {
    helperOf[funcSelector] = helper;
  }

  function batchUpdateHelpers(
    bytes4[] memory funcSelectors,
    address[] memory helpers
  ) external onlyOwner {
    require(funcSelectors.length == helpers.length, 'invalid length');
    for (uint256 i; i < funcSelectors.length;) {
      helperOf[funcSelectors[i]] = helpers[i];

      unchecked {
        ++i;
      }
    }
  }

  function getScaledInputData(
    bytes calldata inputData,
    uint256 newAmount
  ) external view returns (bool isSuccess, bytes memory data) {
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

    (isSuccess, exCallData) = _scaledExecutorCallBytesData(executorData, oldAmount, newAmount);
    if (!isSuccess) return (false, sDescription, '');
    //normal mode swap
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
    desc.amount = newAmount;

    uint256 nReceivers = desc.srcReceivers.length;
    for (uint256 i; i < nReceivers;) {
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
  ) internal pure returns (bool isSuccess, bytes memory) {
    SimpleSwapData memory swapData = abi.decode(data, (SimpleSwapData));

    uint256 nPools = swapData.firstPools.length;
    for (uint256 i = 0; i < nPools;) {
      swapData.firstSwapAmounts[i] = (swapData.firstSwapAmounts[i] * newAmount) / oldAmount;
      unchecked {
        ++i;
      }
    }
    (isSuccess, swapData.positiveSlippageData) =
      _scaledPositiveSlippageFeeData(swapData.positiveSlippageData, oldAmount, newAmount);

    if (!isSuccess) return (false, '');
    return (isSuccess, abi.encode(swapData));
  }

  /// @dev Scale the executorData in case normal swap
  function _scaledExecutorCallBytesData(
    bytes memory data,
    uint256 oldAmount,
    uint256 newAmount
  ) internal view returns (bool isSuccess, bytes memory) {
    SwapExecutorDescription memory executorDesc = abi.decode(data, (SwapExecutorDescription));

    (isSuccess, executorDesc.positiveSlippageData) =
      _scaledPositiveSlippageFeeData(executorDesc.positiveSlippageData, oldAmount, newAmount);

    uint256 nSequences = executorDesc.swapSequences.length;

    for (uint256 i = 0; i < nSequences;) {
      Swap memory swap = executorDesc.swapSequences[i][0];
      bytes4 functionSelector = bytes4(swap.selectorAndFlags);

      address helper = helperOf[functionSelector];
      if (helper == address(0)) return (false, '');

      (bool success, bytes memory returnData) = helper.staticcall(
        abi.encodeWithSelector(functionSelector, abi.encode(swap.data, oldAmount, newAmount), 0)
      );

      if (!success) {
        return (false, '');
      }

      swap.data = abi.decode(returnData, (bytes));

      unchecked {
        ++i;
      }
    }

    return (true, abi.encode(executorDesc));
  }

  function _scaledPositiveSlippageFeeData(
    bytes memory data,
    uint256 oldAmount,
    uint256 newAmount
  ) internal pure returns (bool isSuccess, bytes memory newData) {
    if (data.length > 32) {
      PositiveSlippageFeeData memory psData = abi.decode(data, (PositiveSlippageFeeData));
      uint256 left = uint256(psData.amounts >> 128);
      uint256 right = uint256(uint128(psData.amounts)) * newAmount / oldAmount;
      if (right > type(uint128).max) return (false, '');
      psData.amounts = right | left << 128;
      newData = abi.encode(psData);
    } else if (data.length == 32) {
      uint256 _amounts = abi.decode(data, (uint256));
      uint256 left = uint256(_amounts >> 128);
      uint256 right = uint256(uint128(_amounts)) * newAmount / oldAmount;
      if (right > type(uint128).max) return (false, '');
      _amounts = right | left << 128;
      newData = abi.encode(_amounts);
    }
    return (true, newData);
  }

  function _flagsChecked(uint256 number, uint256 flag) internal pure returns (bool) {
    return number & flag != 0;
  }
}
