import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
const { verify } = require("../helper-functions");

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;

  const { deployer } = await getNamedAccounts();

  const tNativeTokenImpl = await deploy("CWrappedNativeDelegate", {
    from: deployer,
    log: true,
  });

  const tERC20TokenImpl = await deploy("CErc20Delegate", {
    from: deployer,
    log: true,
  });

  await verify(tNativeTokenImpl.address, []);

  await verify(tERC20TokenImpl.address, []);
};
export default func;
func.tags = ["TTokenImplementation"];
func.runAtTheEnd = true;
