// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "./SyntheticToken.sol";
import "./TokenFactory.sol";
import "./CollateralToken.sol";
import "./Timer.sol";
import "./Oracle.sol";

contract FinancialContract {

    TokenFactory public tokenFactory;
    SyntheticToken public syntheticToken;
    CollateralToken public collateralToken;
    Timer public timer;
    Oracle public oracle;

    struct Position {
        uint256 tokensOutstanding;
        uint256 collateralAmount;
    }

    enum LiquidationStatus {
        Liquidated,
        PendingDispute,
        DisputeSucceded,
        DisputeFailed
    }

    struct Liquidation {
        address sponsor;
        address liquidator;
        uint256 liquidationTime;
        address disputer;
        uint256 settlementPrice;
        uint256 collateralLocked; //collateral locked of disputer + liquidator
        uint256 liquidatedCollateral;
        uint256 tokensLiquidated;
        LiquidationStatus status;
    }

    mapping(address => Position) public positions;
    mapping(uint256 => Liquidation) public liquidations;

    uint256 public minNumberOfTokens;
    uint256 public numLiquidations;
    string public priceIdentifier;
    uint256 public minCollateralRatio;
    uint256 public minLiquidationLiveness;

    constructor(address _collateralTokenAddress) {
        minNumberOfTokens = 100;
        tokenFactory = new TokenFactory();
        syntheticToken = tokenFactory.createToken("Synthetic Token", "SNT");
        collateralToken = CollateralToken(_collateralTokenAddress);
        timer = new Timer();
        oracle = new Oracle();
        priceIdentifier = "METH/USD";
        minCollateralRatio = 2;
        minLiquidationLiveness = 2;
    }

    function createPosition(uint256 _numTokens, uint256 _collateralAmount) public {
        require(_numTokens >= minNumberOfTokens, "Position not satisfying min Tokens req");

        Position storage currentPosition = positions[msg.sender];
        currentPosition.tokensOutstanding = _numTokens;
        currentPosition.collateralAmount = _collateralAmount;

        syntheticToken.mint(msg.sender, _numTokens);
        collateralToken.transferFrom(msg.sender, address(this), _collateralAmount);
    }

    function createLiquidation(address _tokenSponsor) public {
        numLiquidations += 1;

        Position storage postionToLiquidate = positions[_tokenSponsor];

        Liquidation storage newLiquidation = liquidations[numLiquidations];
        newLiquidation.sponsor = _tokenSponsor;
        newLiquidation.liquidator = msg.sender;
        newLiquidation.liquidationTime = timer.getTime();
        newLiquidation.disputer = address(0);
        newLiquidation.settlementPrice = 0;
        newLiquidation.collateralLocked = postionToLiquidate.collateralAmount;
        newLiquidation.liquidatedCollateral = postionToLiquidate.collateralAmount;
        newLiquidation.tokensLiquidated = postionToLiquidate.tokensOutstanding;
        newLiquidation.status = LiquidationStatus.Liquidated;

        uint256 tokensToLiquidate = postionToLiquidate.tokensOutstanding;

        //transfer tokens from liquidator
        syntheticToken.transferFrom(msg.sender, address(this), tokensToLiquidate);
        syntheticToken.burn(tokensToLiquidate);

        //for security purposes, liquidator also needs to provide the collateral
        collateralToken.transferFrom(msg.sender, address(this), postionToLiquidate.collateralAmount);

        delete positions[_tokenSponsor];

    }

    function disputeLiquidation(uint256 _liquidationId) public {
        Liquidation storage liquidation = liquidations[_liquidationId];

        liquidation.disputer = msg.sender;
        liquidation.settlementPrice = oracle.getPrice(priceIdentifier);
        liquidation.collateralLocked += liquidation.liquidatedCollateral; // as disputer is also providing the collateral
        liquidation.status = LiquidationStatus.PendingDispute;

        collateralToken.transferFrom(msg.sender, address(this), liquidation.liquidatedCollateral);
    }

    function settleLiquidation(uint256 _liquidationId) public {
        Liquidation storage liquidation = liquidations[_liquidationId];

        require((msg.sender == liquidation.disputer) || 
                (msg.sender == liquidation.liquidator) ||
                (msg.sender == liquidation.sponsor), "Invalid caller");

        if (liquidation.status == LiquidationStatus.Liquidated) {
            require(timer.getTime() > liquidation.liquidationTime + minLiquidationLiveness, "Settling contract before liveness period end");
            collateralToken.transfer(liquidation.liquidator, liquidation.collateralLocked + liquidation.liquidatedCollateral);
        }

        uint256 tokenRedemptionValue = liquidation.tokensLiquidated * liquidation.settlementPrice;

        uint256 requiredCollateral = tokenRedemptionValue * minCollateralRatio;
        bool disputeSucceded = liquidation.liquidatedCollateral >= requiredCollateral;
        liquidation.status = disputeSucceded ? LiquidationStatus.DisputeSucceded : LiquidationStatus.DisputeFailed;

        if (disputeSucceded) {
            collateralToken.transfer(liquidation.disputer, liquidation.collateralLocked);
            collateralToken.transfer(liquidation.sponsor, liquidation.liquidatedCollateral);
        } else {
            collateralToken.transfer(liquidation.liquidator, liquidation.collateralLocked + liquidation.liquidatedCollateral);
        }

        delete liquidations[_liquidationId];
    }
}