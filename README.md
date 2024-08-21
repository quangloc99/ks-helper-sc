# ks-helper-sc
Helper contracts to interact with some KyberSwap's protocols

## Contract Architecture
`InputScalingHelper`: Main contract to scale the swap data of Kyber's router (MetaAggregationRouterV2), 
from oldAmount to newAmount of swap amount

`ScalingDataLib`: Library to scale swap amount of each dex in the route

`InputScalingHelperL2`: **(For Arbitrum, Optimism)** Main contract to scale the swap data of Kyber's router (MetaAggregationRouterV2), 
from oldAmount to newAmount of swap amount

`ScalingDataL2Lib`: **(For Arbitrum, Optimism)** Library to scale swap amount of each dex in the route
## How to use
Function `getScaledInputData` in the `InputScalingHelper` contract
- Input:
    - The encoded data (including the selector) of `swap` and `swapSimpleMode` from the contract `MetaAggregationRouterV2`
    - The new input amount
- Output: New encoded data
- Flows:
    - Decode data of router’s description and executor’s description and scale the input amount. There are 2 cases here of swap and swapSimpleMode.
    - Decode the `Swap[]` data from executor’s data and use the scaling lib to scale amount of each `Swap`
    - Encode the new executor’s data and router’s data
- Requirements: There isn’t any RFQ swap in input data, else it will be reverted with the message “InputScalingHelper: Can not scale RFQ swap”

## Script of Scale Helper V2
Remember to check script before run script at `script/YOUR_SCRIPT_FILE`

### Deployment
- `forge script DeployScaleL1V2Full --rpc-url mainnet --chain-id 1 --gas-price 10000000000 --broadcast`

### Upgrade
Clean and rebuild before run script
Set flag sender 
Set reference contract inside script
- `forge clean && forge build`
- `forge script UpgradeScaleHelperL1V2 --rpc-url mainnet --chain-id 1 --gas-price 10000000000 --sender <OWNER ADDRESS OF PROXY> --broadcast`