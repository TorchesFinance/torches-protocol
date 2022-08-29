pragma solidity ^0.5.16;

import "./compound/EIP20Interface.sol";

interface IRewarder {
    function onMojitoReward(address user, uint256 newLpAmount) external;

    function pendingTokens(address user) external view returns (uint256 pending);

    function rewardToken() external view returns (EIP20Interface);
}
