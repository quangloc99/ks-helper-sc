// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import './Common.sol';
import 'src/interfaces/IExecutorHelperL2.sol';

/// @title DexReader7
/// @notice Contain functions to decode dex data
/// @dev For this repo's scope, we only care about swap amounts, so we just need to decode until we get swap amounts
contract DexReader7 is Common {
  function readMaverickV2(
    bytes memory data,
    address tokenIn,
    bool isFirstDex,
    address nextPool,
    bool getPoolOnly
  ) public view returns (bytes memory) {
    uint256 startByte;
    IExecutorHelperL2.MaverickV2 memory swap;
    // decode
    (swap.pool, startByte) = _readPool(data, startByte);
    if (getPoolOnly) return abi.encode(swap);

    if (isFirstDex) {
      (swap.collectAmount, startByte) = _readUint128AsUint256(data, startByte);
    } else {
      bool collect;
      (collect, startByte) = _readBool(data, startByte);
      swap.collectAmount = collect ? type(uint256).max : 0;
    }

    return abi.encode(swap);
  }

  function readIntegral(
    bytes memory data,
    address tokenIn,
    bool isFirstDex,
    address nextPool,
    bool getPoolOnly
  ) public view returns (bytes memory) {
    uint256 startByte;
    IExecutorHelperL2.Integral memory swap;
    // decode
    (swap.pool, startByte) = _readPool(data, startByte);
    if (getPoolOnly) return abi.encode(swap);

    if (isFirstDex) {
      (swap.collectAmount, startByte) = _readUint128AsUint256(data, startByte);
    } else {
      bool collect;
      (collect, startByte) = _readBool(data, startByte);
      swap.collectAmount = collect ? type(uint256).max : 0;
    }

    return abi.encode(swap);
  }
}
