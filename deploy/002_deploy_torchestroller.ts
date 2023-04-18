import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
const { verify } = require("../helper-functions");

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy, get, save } = deployments;

  const { deployer } = await getNamedAccounts();

  const torchestrollerImpl = await deploy("Torchestroller_Implementation", {
    from: deployer,
    contract: "Torchestroller",
    log: true,
  });

  // const unitrollerAddress = (await get('Unitroller')).address;
  // // update Torchestroller ABI
  // await save('Torchestroller', {
  //   abi: torchestrollerImpl.abi,
  //   address: unitrollerAddress
  // });

  await verify(torchestrollerImpl.address, []);
};
export default func;
func.tags = ["Torchestroller"];
