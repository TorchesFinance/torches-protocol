const InterestModel = artifacts.require("CommonJumpInterestModel");
const Torchestroller = artifacts.require("Torchestroller");
const wrappedNativeDelegate = artifacts.require("CWrappedNativeDelegate");
const wrappedNativeDelegator = artifacts.require("CWrappedNativeDelegator");
const Unitroller = artifacts.require("Unitroller");
const CompoundLens = artifacts.require("CompoundLens");
const ChainLinkPriceOracle = artifacts.require("ChainlinkAdaptor");
const TorchesConfig = artifacts.require("TorchesConfig");
const Maximillion = artifacts.require("Maximillion");

// Mock Tokens
const TetherToken = artifacts.require("TetherToken");
const MockWETH = artifacts.require("MockWETH");

// Parameters
const closeFactor = (0.5e18).toString();
const liquidationIncentive = (1.1e18).toString();
const reserveFactor = (0.6e18).toString();

// 20 * 60 * 24 * 365 (BlockTime: 3s)
let blocksPerYear = 10512000;

let addressFactory = {};
module.exports = async function (deployer, network) {
  await deployer.deploy(Unitroller);
  await deployer.deploy(Torchestroller);
  await deployer.deploy(CompoundLens);
  await deployer.deploy(
    TorchesConfig,
    "0x0000000000000000000000000000000000000000"
  );

  addressFactory["Torchestroller"] = Unitroller.address;
  addressFactory["TorchesConfig"] = TorchesConfig.address;
  addressFactory["CompoundLens"] = CompoundLens.address;

  let unitrollerInstance = await Unitroller.deployed();
  let TorchestrollerInstance = await Torchestroller.deployed();
  let torchesConfigInstance = await TorchesConfig.deployed();
  let admin = await TorchestrollerInstance.admin();
  console.log("admin: ", admin);

  await unitrollerInstance._setPendingImplementation(Torchestroller.address);
  await TorchestrollerInstance._become(Unitroller.address);
  await torchesConfigInstance._setPendingSafetyGuardian(admin);
  await torchesConfigInstance._acceptSafetyGuardian();
  const baseRatePerYear = (0.03e18).toString();
  const multiplierPerYear = (0.3e18).toString();
  const jumpMultiplierPerYear = (5e18).toString();
  const kink = (0.9e18).toString();

  let proxiedTorchestroller = await Torchestroller.at(Unitroller.address);

  await proxiedTorchestroller._setTorchesConfig(TorchesConfig.address);
  console.log(
    "Done to set torches config.",
    await proxiedTorchestroller.torchesConfig()
  );

  await proxiedTorchestroller._setLiquidationIncentive(liquidationIncentive);
  console.log("Done to set liquidation incentive.");
  let incentive = await proxiedTorchestroller.liquidationIncentiveMantissa();
  console.log("New incentive: ", incentive.toString());

  await proxiedTorchestroller._setCloseFactor(closeFactor);
  result = await proxiedTorchestroller.closeFactorMantissa();
  console.log("Done to set close factor with value: ", result.toString());

  if (network == "kcctest" || network == "kcc") {
    let kcsToken = "0xB296bAb2ED122a85977423b602DdF3527582A3DA";
    let kcsPriceSource = "0xae3DB39196012a7bF6D38737192F260cdFE1E7Ec";
    if (network == "kcc") {
      kcsToken = "0x4446fc4eb47f2f6586f9faab68b3498f86c07521";
      kcsPriceSource = "0xAFC9c849b1a784955908d91EE43A3203fBC1f950";
    }
    await deployer.deploy(ChainLinkPriceOracle, kcsPriceSource);
    let priceOracleAddress = ChainLinkPriceOracle.address;
    await deployer.deploy(
      InterestModel,
      blocksPerYear,
      baseRatePerYear,
      multiplierPerYear,
      jumpMultiplierPerYear,
      kink
    );
    addressFactory["InterestRateModel"] = InterestModel.address;
    let proxiedTorchestroller = await Torchestroller.at(Unitroller.address);
    await proxiedTorchestroller._setPriceOracle(priceOracleAddress);
    console.log(
      "Done to set price oracle.",
      await proxiedTorchestroller.oracle()
    );
    addressFactory["PriceOracle"] = priceOracleAddress;
    await deployer.deploy(wrappedNativeDelegate);
    await deployer.deploy(
      wrappedNativeDelegator,
      kcsToken,
      Unitroller.address,
      InterestModel.address,
      (0.02e18).toString(),
      "Torches KCS",
      "tKCS",
      18,
      admin,
      wrappedNativeDelegate.address,
      "0x0"
    );
    const wrappedNativeInstance = await wrappedNativeDelegator.deployed();
    await wrappedNativeInstance._setReserveFactor(reserveFactor);
    console.log("Done to set reserve factor to %s", reserveFactor);
    await proxiedTorchestroller._supportMarket(wrappedNativeDelegator.address);
    console.log("Done to support market tKCS: ", wrappedNativeInstance.address);
    let collateralFactor = (0.8e18).toString();
    await proxiedTorchestroller._setCollateralFactor(
      wrappedNativeInstance.address,
      collateralFactor
    );
    console.log(
      "Done to set collateral factor %s for tKCS %s",
      collateralFactor,
      wrappedNativeInstance.address
    );
    addressFactory["tKCS"] = wrappedNativeInstance.address;
    await deployer.deploy(Maximillion, wrappedNativeInstance.address);
    addressFactory["Maximillion"] = Maximillion.address;
  }
  console.log(
    "================= Copy and record below addresses =============="
  );
  console.log(addressFactory);
};
