pragma solidity ^0.5.16;
pragma experimental ABIEncoderV2;

import "./compound/EIP20Interface.sol";
import "./IRewarder.sol";

interface MasterChefV2 {

    struct UserInfo {
        uint256 amount;
        int256 rewardDebt;
    }

    struct PoolInfo {
        EIP20Interface lpToken;             // Address of LP token contract.
        uint256 allocPoint;         // How many allocation points assigned to this pool. MJTs to distribute per block.
        uint256 lastRewardBlock;    // Last block number that MJTs distribution occurs.
        uint256 accMojitoPerShare;  // Accumulated MJTs per share, times 1e12. See below.
        IRewarder rewarder;
    }

    function poolInfo(uint pid) external view returns(PoolInfo memory);
    function deposit(uint256 pid, uint256 amount) external;
    function withdraw(uint256 pid, uint256 amount) external;
    function harvest(uint256 pid, address to) external;
    function mojito() view external returns (EIP20Interface);
    function userInfo(uint256 pid, address account) view external returns (UserInfo memory);
    function pendingMojito(uint256 _pid, address _user) external view returns (uint256);

    function enterStaking(uint256 _amount) external;
    function leaveStaking(uint256 _amount) external;
}
