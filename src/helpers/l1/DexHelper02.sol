// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IExecutorHelperStruct} from 'src/interfaces/IExecutorHelperStruct.sol';

contract DexHelper02 {
  function executeMaverickV2(
    bytes memory scalingData,
    uint256 /*  */
  ) public pure returns (bytes memory) {
    (bytes memory data, uint256 oldAmount, uint256 newAmount) =
      abi.decode(scalingData, (bytes, uint256, uint256));

    IExecutorHelperStruct.MaverickV2 memory structData =
      abi.decode(data, (IExecutorHelperStruct.MaverickV2));
    structData.collectAmount = (structData.collectAmount * newAmount) / oldAmount;
    return abi.encode(structData);
  }

  function executeIntegral(
    bytes memory scalingData,
    uint256 /*  */
  ) public pure returns (bytes memory) {
    (bytes memory data, uint256 oldAmount, uint256 newAmount) =
      abi.decode(scalingData, (bytes, uint256, uint256));

    IExecutorHelperStruct.MaverickV2 memory structData =
      abi.decode(data, (IExecutorHelperStruct.MaverickV2));
    structData.collectAmount = (structData.collectAmount * newAmount) / oldAmount;
    return abi.encode(structData);
  }

  function executeUsd0PP(
    bytes memory scalingData,
    uint256 /*  */
  ) public pure returns (bytes memory) {
    (bytes memory data, uint256 oldAmount, uint256 newAmount) =
      abi.decode(scalingData, (bytes, uint256, uint256));

    uint256 amount = abi.decode(data, (uint256));
    amount = (amount * newAmount) / oldAmount;
    return abi.encode(amount);
  }
}
