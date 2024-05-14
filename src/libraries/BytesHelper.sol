pragma solidity ^0.8.0;

library BytesHelper {
  function update(
    bytes calldata originalCalldata,
    uint256 newAmount,
    uint256 amountInOffset
  ) external pure returns (bytes memory) {
    require(amountInOffset + 32 <= originalCalldata.length, 'Offset out of bounds');

    // Create a mutable copy of the original calldata
    bytes memory updatedCalldata = originalCalldata;

    // Convert newAmount to bytes32
    bytes32 newAmountBytes = bytes32(newAmount);

    // Update the 32 bytes at the specified offset with the new amount
    for (uint256 i = 0; i < 32; i++) {
      updatedCalldata[amountInOffset + i] = newAmountBytes[i];
    }

    return updatedCalldata;
  }
}
