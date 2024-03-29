pragma solidity ^0.5.16;
pragma experimental ABIEncoderV2;

import "../CErc20.sol";
import "../../TToken.sol";
import "../CToken.sol";
import "../PriceOracle.sol";
import "../EIP20Interface.sol";
import "../SafeMath.sol";
import "../../TMLPDelegate.sol";

interface ComptrollerLensInterface {
    function markets(address) external view returns (bool, uint);
    function oracle() external view returns (PriceOracle);
    function getAccountLiquidity(address) external view returns (uint, uint, uint);
    function getAssetsIn(address) external view returns (CToken[] memory);
    function claimComp(address) external;
    function compAccrued(address) external view returns (uint);
}

contract CompoundLens {
    using SafeMath for uint256;

    struct CTokenMetadata {
        address cToken;
        uint exchangeRateCurrent;
        uint supplyRatePerBlock;
        uint borrowRatePerBlock;
        uint reserveFactorMantissa;
        uint totalBorrows;
        uint totalReserves;
        uint totalSupply;
        uint totalCash;
        bool isListed;
        uint collateralFactorMantissa;
        address underlyingAssetAddress;
        uint cTokenDecimals;
        uint underlyingDecimals;
    }

    function cTokenMetadataExpand(TToken cToken) public returns (
        uint collateralFactorMantissa,
        uint exchangeRateCurrent,
        uint supplyRatePerBlock,
        uint borrowRatePerBlock,
        uint reserveFactorMantissa,
        uint totalBorrows,
        uint totalReserves, uint totalSupply, uint totalCash,
        bool isListed, address underlyingAssetAddress,
        uint underlyingDecimals) {
        CTokenMetadata memory cTokenData = cTokenMetadata(cToken);
        exchangeRateCurrent = cTokenData.exchangeRateCurrent;
        supplyRatePerBlock = cTokenData.supplyRatePerBlock;
        borrowRatePerBlock = cTokenData.borrowRatePerBlock;
        reserveFactorMantissa = cTokenData.reserveFactorMantissa;
        totalBorrows = cTokenData.totalBorrows;
        totalReserves = cTokenData.totalReserves;
        totalSupply = cTokenData.totalSupply;
        totalCash = cTokenData.totalCash;
        isListed = cTokenData.isListed;
        collateralFactorMantissa = cTokenData.collateralFactorMantissa;
        underlyingAssetAddress = cTokenData.underlyingAssetAddress;
        underlyingDecimals = cTokenData.underlyingDecimals;
    }

    function cTokenMetadata(TToken cToken) public returns (CTokenMetadata memory) {
        uint exchangeRateCurrent = cToken.exchangeRateCurrent();
        ComptrollerLensInterface comptroller = ComptrollerLensInterface(address(cToken.comptroller()));
        (bool isListed, uint collateralFactorMantissa) = comptroller.markets(address(cToken));
        address underlyingAssetAddress;
        uint underlyingDecimals;

        if (cToken.isNativeToken()) {
            underlyingAssetAddress = address(0);
            underlyingDecimals = 18;
        } else {
            CErc20 cErc20 = CErc20(address(cToken));
            underlyingAssetAddress = cErc20.underlying();
            underlyingDecimals = EIP20Interface(cErc20.underlying()).decimals();
        }

        return CTokenMetadata({
            cToken: address(cToken),
            exchangeRateCurrent: exchangeRateCurrent,
            supplyRatePerBlock: cToken.supplyRatePerBlock(),
            borrowRatePerBlock: cToken.borrowRatePerBlock(),
            reserveFactorMantissa: cToken.reserveFactorMantissa(),
            totalBorrows: cToken.totalBorrows(),
            totalReserves: cToken.totalReserves(),
            totalSupply: cToken.totalSupply(),
            totalCash: cToken.getCash(),
            isListed: isListed,
            collateralFactorMantissa: collateralFactorMantissa,
            underlyingAssetAddress: underlyingAssetAddress,
            cTokenDecimals: cToken.decimals(),
            underlyingDecimals: underlyingDecimals
        });
    }

    function cTokenMetadataAll(TToken[] calldata cTokens) external returns (CTokenMetadata[] memory) {
        uint cTokenCount = cTokens.length;
        CTokenMetadata[] memory res = new CTokenMetadata[](cTokenCount);
        for (uint i = 0; i < cTokenCount; i++) {
            res[i] = cTokenMetadata(cTokens[i]);
        }
        return res;
    }

    struct CTokenBalances {
        address cToken;
        uint balanceOf;
        uint borrowBalanceCurrent;
        uint balanceOfUnderlying;
        uint tokenBalance;
        uint tokenAllowance;
    }

    function cTokenBalances(TToken cToken, address payable account) public returns (CTokenBalances memory) {
        uint balanceOf = cToken.balanceOf(account);
        uint borrowBalanceCurrent = cToken.borrowBalanceCurrent(account);
        uint balanceOfUnderlying = cToken.balanceOfUnderlying(account);
        uint tokenBalance;
        uint tokenAllowance;

        if (cToken.isNativeToken()) {
            tokenBalance = account.balance;
            tokenAllowance = account.balance;
        } else {
            CErc20 cErc20 = CErc20(address(cToken));
            EIP20Interface underlying = EIP20Interface(cErc20.underlying());
            tokenBalance = underlying.balanceOf(account);
            tokenAllowance = underlying.allowance(account, address(cToken));
        }

        return CTokenBalances({
            cToken: address(cToken),
            balanceOf: balanceOf,
            borrowBalanceCurrent: borrowBalanceCurrent,
            balanceOfUnderlying: balanceOfUnderlying,
            tokenBalance: tokenBalance,
            tokenAllowance: tokenAllowance
        });
    }

    function cTokenBalancesAll(TToken[] calldata cTokens, address payable account) external returns (CTokenBalances[] memory) {
        uint cTokenCount = cTokens.length;
        CTokenBalances[] memory res = new CTokenBalances[](cTokenCount);
        for (uint i = 0; i < cTokenCount; i++) {
            res[i] = cTokenBalances(cTokens[i], account);
        }
        return res;
    }

    struct CTokenUnderlyingPrice {
        address cToken;
        uint underlyingPrice;
    }

    function cTokenUnderlyingPrice(CToken cToken) public view returns (CTokenUnderlyingPrice memory) {
        ComptrollerLensInterface comptroller = ComptrollerLensInterface(address(cToken.comptroller()));
        PriceOracle priceOracle = comptroller.oracle();

        return CTokenUnderlyingPrice({
            cToken: address(cToken),
            underlyingPrice: priceOracle.getUnderlyingPrice(cToken)
        });
    }

    function cTokenUnderlyingPriceAll(CToken[] calldata cTokens) external view returns (CTokenUnderlyingPrice[] memory) {
        uint cTokenCount = cTokens.length;
        CTokenUnderlyingPrice[] memory res = new CTokenUnderlyingPrice[](cTokenCount);
        for (uint i = 0; i < cTokenCount; i++) {
            res[i] = cTokenUnderlyingPrice(cTokens[i]);
        }
        return res;
    }

    struct AccountLimits {
        CToken[] markets;
        uint liquidity;
        uint shortfall;
    }

    function getAccountLimits(ComptrollerLensInterface comptroller, address account) public view returns (AccountLimits memory) {
        (uint errorCode, uint liquidity, uint shortfall) = comptroller.getAccountLiquidity(account);
        require(errorCode == 0);

        return AccountLimits({
            markets: comptroller.getAssetsIn(account),
            liquidity: liquidity,
            shortfall: shortfall
        });
    }

    function getAccountLimitsExpand(ComptrollerLensInterface comptroller, address account) public view returns (uint liquidity, uint shortfall,  CToken[] memory markets) {
        AccountLimits memory accountLimits = getAccountLimits(comptroller, account);
        liquidity = accountLimits.liquidity;
        shortfall = accountLimits.shortfall;
        markets = accountLimits.markets;
    }

    function getCompBalanceWithAccrued(EIP20Interface comp, ComptrollerLensInterface comptroller, address account) external returns (uint balance, uint allocated) {
        balance = comp.balanceOf(account);
        comptroller.claimComp(account);
        uint newBalance = comp.balanceOf(account);
        uint accrued = comptroller.compAccrued(account);
        uint total = add(accrued, newBalance, "sum comp total");
        allocated = sub(total, balance, "sub allocated");
    }

    function getLpRewardPending(address lpTtoken, uint8 rewardTokenCount, address account) public returns (uint[] memory rewards) {
        TMLPDelegate delegate = TMLPDelegate(lpTtoken);

        uint[] memory rewardTokensBalance = new uint[](rewardTokenCount);
        for (uint8 i = 0; i < rewardTokenCount; i++) {
            rewardTokensBalance[i] = CErc20(delegate.rewardsTokens(i)).balanceOf(account);
        }

        delegate.claimRewards(account);
        rewards = new uint[](rewardTokenCount);
        for (uint8 i = 0; i < rewardTokenCount; i++) {
            rewards[i] = sub(CErc20(delegate.rewardsTokens(i)).balanceOf(account), rewardTokensBalance[i], "sub allocated");
        }
    }

    struct TMLPDIRParam {
        MasterChefV2 pool;
        uint reward;
        uint totalAllocPoint;
        uint stakeReward;
        uint farmReward;
        uint stakeDir;
        uint farmDir;
        uint256 tokenPerBlock;
    }

    // DIR for Daily Interest Rate
    function getTMLPDIR(TMLPDelegate lp, uint mojitoPrice, uint priceB, uint priceLp) public view returns(uint dirA, uint dirB) {
        TMLPDIRParam memory vars;

        vars.pool = lp.mojitoPool();
        // reward per block
        vars.reward = vars.pool.reward(block.number);
        vars.totalAllocPoint = vars.pool.totalAllocPoint();

        MasterChefV2.PoolInfo memory poolInfo = vars.pool.poolInfo(lp.pid());
        MasterChefV2.PoolInfo memory stakeInfo = vars.pool.poolInfo(0);

        // 3 seconds per block
        // 60 * 60 * 24 / 3 = 28800
        vars.stakeReward = vars.reward.mul(stakeInfo.allocPoint).div(vars.totalAllocPoint);
        vars.farmReward = vars.reward.mul(poolInfo.allocPoint).div(vars.totalAllocPoint);

        vars.stakeDir = vars.stakeReward.mul(1e18).mul(28800).div(stakeInfo.lpToken.balanceOf(address(vars.pool)));
        vars.farmDir = vars.farmReward.mul(1e18).mul(28800).div(poolInfo.lpToken.balanceOf(address(vars.pool))).mul(mojitoPrice).div(priceLp);

        dirA = add(vars.farmDir, vars.farmDir.mul(vars.stakeDir).div(1e18), "dir err");

        if (address(poolInfo.rewarder) != address(0)) {
            vars.tokenPerBlock = poolInfo.rewarder.tokenPerBlock();
            // 3 seconds per block
            dirB = vars.tokenPerBlock.mul(1e18).mul(28800).div(poolInfo.lpToken.balanceOf(address(vars.pool))).mul(priceB).div(priceLp);
        }
    }

    function add(uint a, uint b, string memory errorMessage) internal pure returns (uint) {
        uint c = a + b;
        require(c >= a, errorMessage);
        return c;
    }

    function sub(uint a, uint b, string memory errorMessage) internal pure returns (uint) {
        require(b <= a, errorMessage);
        uint c = a - b;
        return c;
    }
}
