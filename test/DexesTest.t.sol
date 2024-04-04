// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import 'forge-std/Test.sol';
import 'forge-std/console.sol';
import 'forge-std/StdJson.sol';
import '@openzeppelin/contracts/utils/Strings.sol';
import '../src/InputScalingHelper.sol';
import './BaseInputScaling.t.sol';

contract DexesTest is BaseInputScalingTest {
  using stdJson for string;

  address private constant ETH_ADDRESS = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

  function _executeTest(SwapTx memory swap, string memory url, uint256 amount) internal {
    vm.createSelectFork(url, swap.blockNumber - 1);
    alice = swap.sender;
    router = IMetaAggregationRouterV2(payable(routerAddress));
    bytes memory inputData = swap.encodedData;

    //non-scaled swap
    uint256 snapshot = vm.snapshot();
    uint256 initialResult = _swap(inputData, swap.value);

    //scaled swap increase
    vm.revertTo(snapshot);
    uint256 newAmount = (amount * 110) / 100;
    bytes memory newData = scaleHelper.getScaledInputData(inputData, newAmount);
    uint256 afterResult = _swap(newData, newAmount);
    assertGt(afterResult, initialResult);
    console.log(initialResult, afterResult);

    //scaled swap decrease
    vm.revertTo(snapshot);
    newAmount = (amount * 90) / 100;
    newData = scaleHelper.getScaledInputData(inputData, newAmount);
    afterResult = _swap(newData, newAmount);
    assertLt(afterResult, initialResult);
    console.log(initialResult, afterResult);
  }

  function testScaleUniswap() public {
    //swap amount = 1 ether
    SwapTx memory swap = _readInput(swapInputPath, '.uniswap_ethereum_1_ETH_USDC');
    string memory url = vm.envString('ETH_NODE_URL');
    _executeTest(swap, url, 1 ether);
  }

  function testScaleBalancer() public {
    //swap amount = 1 ether
    SwapTx memory swap = _readInput(swapInputPath, '.balancer_ethereum_1_ETH_USDC');
    string memory url = vm.envString('ETH_NODE_URL');
    _executeTest(swap, url, 1 ether);
  }

  function testScaleCurve() public {
    //swap amount = 1 ether
    SwapTx memory swap = _readInput(swapInputPath, '.curve_ethereum_1_ETH_USDC');
    string memory url = vm.envString('ETH_NODE_URL');
    _executeTest(swap, url, 1 ether);
  }

  function testScaleKyberDMM() public {
    //swap amount = 1 ether
    SwapTx memory swap = _readInput(swapInputPath, '.kyberDMM_ethereum_1_ETH_USDC');
    string memory url = vm.envString('ETH_NODE_URL');
    _executeTest(swap, url, 1 ether);
  }

  function testScaleUniswapV3() public {
    //swap amount = 1 ether
    SwapTx memory swap = _readInput(swapInputPath, '.uniswapv3_ethereum_1_ETH_USDC');
    string memory url = vm.envString('ETH_NODE_URL');
    _executeTest(swap, url, 1 ether);
  }

  function testScaleStable() public {
    //swap amount = 1 ether
    SwapTx memory swap = _readInput(swapInputPath, '.saddle_ethereum_1_WETH_SETH');
    string memory url = vm.envString('ETH_NODE_URL');
    _executeTest(swap, url, 1 ether);
  }

  function testScaleDodo() public {
    //swap amount = 1 ether
    SwapTx memory swap = _readInput(swapInputPath, '.dodo_ethereum_1000_USDC_USDT');
    string memory url = vm.envString('ETH_NODE_URL');
    _executeTest(swap, url, 1e9);
  }

  function testScaleVelodrome() public {
    //swap amount = 1 ether
    SwapTx memory swap = _readInput(swapInputPath, '.velodrome_optimism_1_ETH_USDC');
    string memory url = vm.envString('OP_NODE_URL');
    _executeTest(swap, url, 1 ether);
  }

  function testScaleGMX() public {
    //swap amount = 1 ether
    SwapTx memory swap = _readInput(swapInputPath, '.gmx_arbitrum_1_WETH_USDC');
    string memory url = vm.envString('ARBITRUM_NODE_URL');
    _executeTest(swap, url, 1 ether);
  }

  function testScaleFrax() public {
    //swap amount = 1 ether
    SwapTx memory swap = _readInput(swapInputPath, '.frax_ethereum_1_ETH_USDC');
    string memory url = vm.envString('ETH_NODE_URL');
    _executeTest(swap, url, 1 ether);
  }

  function testScalePlatypus() public {
    //swap amount = 1 ether
    SwapTx memory swap = _readInput(swapInputPath, '.platypus_avalanche_1_WAVAX_SAVAX');
    string memory url = vm.envString('AVAX_NODE_URL');
    _executeTest(swap, url, 1 ether);
  }

  function testScaleCamelot() public {
    //swap amount = 1 ether
    SwapTx memory swap = _readInput(swapInputPath, '.camelot_arbitrum_1_ETH_USDC');
    string memory url = vm.envString('ARBITRUM_NODE_URL');
    _executeTest(swap, url, 1 ether);
  }

  function testScaleWstETH() public {
    //swap amount = 1 ether
    SwapTx memory swap = _readInput(swapInputPath, '.wstETH_ethereum_1_stETH_wstETH');
    string memory url = vm.envString('ETH_NODE_URL');
    _executeTest(swap, url, 1 ether);
  }
}
