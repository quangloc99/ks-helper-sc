// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

contract BaseConfig {
  enum DexName {
    SwaapV2, // 0
    Bebop, // 1
    Native, // 2
    KyberLO,
    KyberDSLO,
    UNI,
    KyberDMM,
    Velodrome,
    Fraxswap,
    Camelot,
    StableSwap, // 10
    GMX,
    Mantis,
    Wombat,
    WooFiV2,
    Smardex,
    SolidlyV2,
    NomiswapStable,
    BancorV3,
    Curve,
    PancakeStableSwap, // 20
    UniV3ProMM,
    RFQ,
    BalancerV2,
    DODO,
    Synthetix,
    Hashflow,
    PSM,
    WSTETH,
    StEth,
    Platypus, // 30
    Maverick,
    SyncSwap,
    AlgebraV1,
    BalancerBatch,
    iZiSwap,
    TraderJoeV2,
    LevelFiV2,
    GMXGLP,
    Vooi, // 40
    VelocoreV2,
    MaticMigrate,
    Kokonut,
    BalancerV1,
    ArbswapStable,
    BancorV2,
    Ambient,
    UniV1,
    LighterV2,
    EtherFieETH, // 50
    EtherFiWeETH,
    Kelp,
    EthenaSusde,
    RocketPool,
    MakersDAI,
    Renzo,
    WBETH,
    MantleETH,
    FrxETH,
    SfrxETH, // 60
    SfrxETHConvertor,
    SwellETH,
    RswETH,
    StaderETHx,
    OriginETH,
    PrimeETH,
    MantleUsd,
    BedrockUniETH,
    MaiPSM,
    PufferFinance, // 70
    SymbioticLRT,
    MaverickV2,
    Integral,
    Usd0PP
  }
}
