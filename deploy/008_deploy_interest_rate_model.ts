import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';
const { verify } = require("../helper-functions");

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {deployments, getNamedAccounts} = hre;
    const {deploy} = deployments;
    const parseEther = hre.ethers.utils.parseEther;

    const {deployer} = await getNamedAccounts();

    let blocksPerYear = 10512000; // 60×60×24×365÷3
    let baseRate = parseEther('0.01');
    let multiplier = parseEther('0.15');
    let jump = parseEther('3');
    let kink = parseEther('0.9');

    const sKCSIRM=await deploy('SKCSIRM', {
        from: deployer,
        contract: 'CommonJumpInterestModel',
        args: [
            blocksPerYear,
            baseRate,
            multiplier,
            jump,
            kink,
        ],
        log: true
    });

    await verify(sKCSIRM.address, [
        blocksPerYear,
        baseRate,
        multiplier,
        jump,
        kink,
    ]);
}
export default func;
func.tags = ['InterestRateModel'];
