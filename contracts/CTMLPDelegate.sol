pragma solidity ^0.5.16;
pragma experimental ABIEncoderV2;

import "./compound/CErc20Delegate.sol";
import "./compound/EIP20Interface.sol";
import "./Torchestroller.sol";
import "./IRewarder.sol";
import "./MasterChefV2.sol";

/**
 * @title mojito LP Contract
 * @notice TToken which wraps mojito's LP token
 */
contract CTMLPDelegate is CErc20Delegate {
    /**
     * @notice mojitoPool
     */
    MasterChefV2 public mojitoPool;

    /**
     * @notice Pool ID of this LP in mojitoPool
     */
    uint public pid;

    /**
     * @notice reward tokens
     */
    address[] public rewardsTokens;

    /**
     * @notice Container for rewards state
     * @member balance The balance of token
     * @member index The last updated token index
     */
    struct RewardState {
        uint balance;
        uint index;
    }

    /**
     * @notice The state of LP supply
     */
    mapping(address => RewardState) public lpSupplyStates;

    /**
     * @notice The index of every LP supplier
     */
    mapping(address => mapping(address => uint)) public lpSupplierIndex;

    /**
     * @notice The token amount of every user
     */
    mapping(address => mapping(address => uint)) public tokenUserAccrued;

    /**
     * @notice Delegate interface to become the implementation
     * @param data The encoded arguments for becoming
     */
    function _becomeImplementation(bytes memory data) public {
        super._becomeImplementation(data);

        (address poolAddress_, uint pid_) = abi.decode(data, (address, uint));
        mojitoPool = MasterChefV2(poolAddress_);
        MasterChefV2.PoolInfo memory poolInfo = mojitoPool.poolInfo(pid_);
        require(underlying == address(poolInfo.lpToken), "mismatch underlying");

        pid = pid_;

        if (rewardsTokens.length == 0) {
            rewardsTokens.push(address(mojitoPool.mojito()));
        }
        if (address(poolInfo.rewarder) != address(0)) {
            address rewardToken = address(IRewarder(poolInfo.rewarder).rewardToken());
            bool exist = false;
            for (uint8 i = 0; i < rewardsTokens.length; i++) {
                if (rewardsTokens[i] == rewardToken) {
                    exist = true;
                    break;
                }
            }
            if (!exist) rewardsTokens.push(rewardToken);
        }

        // Approve moving our LP into the pool contract.
        EIP20Interface(underlying).approve(poolAddress_, uint(-1));
        EIP20Interface(rewardsTokens[0]).approve(poolAddress_, uint(-1));
    }

    /**
     * @notice Manually claim rewards by user
     * @return The amount of mojito rewards user claims
     */
    function claimRewards(address account) public returns (uint) {
        claimRewardsFromMojito();

        updateLPSupplyIndex();
        updateSupplierIndex(account);

        address mojito = address(mojitoPool.mojito());

        // Get user's token accrued.
        for (uint8 i = 0; i < rewardsTokens.length; i++) {
            address token = rewardsTokens[i];

            uint accrued = tokenUserAccrued[account][token];
            if (accrued == 0) continue;

            lpSupplyStates[token].balance = sub_(lpSupplyStates[token].balance, accrued);

            if (mojito == token) {
                mojitoPool.leaveStaking(accrued);
            }

            // Clear user's token accrued.
            tokenUserAccrued[account][token] = 0;

            EIP20Interface(token).transfer(account, accrued);
        }

        return 0;
    }

    /*** CErc20 Overrides ***/
    /**
     * lp token does not borrow.
     */
    function borrow(uint borrowAmount) external returns (uint) {
        borrowAmount;
        require(false);
    }

    /**
     * lp token does not repayBorrow.
     */
    function repayBorrow(uint repayAmount) external returns (uint) {
        repayAmount;
        require(false);
    }

    function repayBorrowBehalf(address borrower, uint repayAmount) external returns (uint) {
        borrower;repayAmount;
        require(false);
    }

    function liquidateBorrow(address borrower, uint repayAmount, CTokenInterface cTokenCollateral) external returns (uint) {
        borrower;repayAmount;cTokenCollateral;
        require(false);
    }

    function flashLoan(IERC3156FlashBorrower receiver, address token, uint256 amount, bytes calldata data) external returns (bool) {
        receiver;token;amount;data;
        require(false);
    }

    function _addReserves(uint addAmount) external returns (uint) {
        addAmount;
        require(false);
    }

    function _reduceReserves(uint reduceAmount) external nonReentrant returns (uint) {
        reduceAmount;
        require(false);
    }

    /*** CToken Overrides ***/

    /**
     * @notice Transfer `tokens` tokens from `src` to `dst` by `spender`
     * @param spender The address of the account performing the transfer
     * @param src The address of the source account
     * @param dst The address of the destination account
     * @param tokens The number of tokens to transfer
     * @return Whether or not the transfer succeeded
     */
    function transferTokens(address spender, address src, address dst, uint tokens) internal returns (uint) {
        claimRewardsFromMojito();

        updateLPSupplyIndex();
        updateSupplierIndex(src);
        updateSupplierIndex(dst);

        return super.transferTokens(spender, src, dst, tokens);
    }

    /*** Safe Token ***/

    /**
     * @notice Gets balance of this contract in terms of the underlying
     * @return The quantity of underlying tokens owned by this contract
     */
    function getCashPrior() internal view returns (uint) {
        MasterChefV2.UserInfo memory userInfo = mojitoPool.userInfo(pid, address(this));
        return userInfo.amount;
    }

    /**
     * @notice Transfer the underlying to this contract and sweep into master chef
     * @param from Address to transfer funds from
     * @param amount Amount of underlying to transfer
     * @return The actual amount that is transferred
     */
    function doTransferIn(address from, uint amount) internal returns (uint) {
        // Perform the EIP-20 transfer in
        super.doTransferIn(from, amount);

        // Deposit to mojito pool.
        mojitoPool.deposit(pid, amount);

        claimRewardsFromMojito();

        updateLPSupplyIndex();
        updateSupplierIndex(from);

        return amount;
    }

    /**
     * @notice Transfer the underlying from this contract, after sweeping out of master chef
     * @param to Address to transfer funds to
     * @param amount Amount of underlying to transfer
     */
    function doTransferOut(address payable to, uint amount) internal {
        // Withdraw the underlying tokens from mojito pool.
        mojitoPool.withdraw(pid, amount);
        super.doTransferOut(to, amount);
    }

    function seizeInternal(address seizerToken, address liquidator, address borrower, uint seizeTokens) internal returns (uint) {
        claimRewardsFromMojito();

        updateLPSupplyIndex();
        updateSupplierIndex(liquidator);
        updateSupplierIndex(borrower);

        address safetyVault = Torchestroller(address(comptroller)).torchesConfig().safetyVault();
        updateSupplierIndex(safetyVault);

        return super.seizeInternal(seizerToken, liquidator, borrower, seizeTokens);
    }

    /**
     * @notice Sender redeems cTokens in exchange for the underlying asset
     * @dev Accrues interest whether or not the operation succeeds, unless reverted
     * @param redeemTokens The number of cTokens to redeem into underlying
     * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
     */
    function redeem(uint redeemTokens) external returns (uint) {
        // claim user's reward first
        claimRewards(msg.sender);

        return redeemInternal(redeemTokens);
    }

    /**
     * @notice Sender redeems cTokens in exchange for a specified amount of underlying asset
     * @dev Accrues interest whether or not the operation succeeds, unless reverted
     * @param redeemAmount The amount of underlying to redeem
     * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
     */
    function redeemUnderlying(uint redeemAmount) external returns (uint) {
        // claim user's reward first
        claimRewards(msg.sender);

        return redeemUnderlyingInternal(redeemAmount);
    }

    /*** Internal functions ***/

    function claimRewardsFromMojito() internal {
        mojitoPool.deposit(pid, 0);

        uint256 pending = mojitoPool.pendingMojito(0, address(this));
        mojitoPool.enterStaking(add_(pending, mojitoPool.mojito().balanceOf(address(this))));
    }

    function updateLPSupplyIndex() internal {
        address mojito = address(mojitoPool.mojito());
        for (uint8 i = 0; i < rewardsTokens.length; i++) {
            address token = rewardsTokens[i];

            uint balance = token == mojito ? mojitoBalance() : tokenBalance(token);
            uint tokenAccrued = sub_(balance, lpSupplyStates[token].balance);
            uint supplyTokens = this.totalSupply();
            Double memory ratio = supplyTokens > 0 ? fraction(tokenAccrued, supplyTokens) : Double({mantissa: 0});
            Double memory index = add_(Double({mantissa: lpSupplyStates[token].index}), ratio);

            lpSupplyStates[token].index = index.mantissa;
            lpSupplyStates[token].balance = balance;
        }
    }

    function updateSupplierIndex(address supplier) internal {
        for (uint8 i = 0; i < rewardsTokens.length; i++) {
            address token = rewardsTokens[i];

            Double memory supplyIndex = Double({mantissa: lpSupplyStates[token].index});
            Double memory supplierIndex = Double({mantissa: lpSupplierIndex[supplier][token]});
            Double memory deltaIndex = sub_(supplyIndex, supplierIndex);

            if (deltaIndex.mantissa > 0) {
                uint supplierTokens = this.balanceOf(supplier);
                uint supplierDelta = mul_(supplierTokens, deltaIndex);
                tokenUserAccrued[supplier][token] = add_(tokenUserAccrued[supplier][token], supplierDelta);
                lpSupplierIndex[supplier][token] = supplyIndex.mantissa;
            }
        }
    }

    function mojitoBalance() internal view returns (uint) {
        MasterChefV2.UserInfo memory info = mojitoPool.userInfo(0, address(this));
        return info.amount;
    }

    function tokenBalance(address token) internal view returns (uint) {
        return EIP20Interface(token).balanceOf(address(this));
    }
}
