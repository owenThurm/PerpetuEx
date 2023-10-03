//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

interface IPerpetuEx {
    /// Errors
    error PerpetuEx__InvalidCollateral();
    error PerpetuEx__InvalidSize();
    error PerpetuEx__InvalidAmount();
    error PerpetuEx__InsufficientCollateral();
    error PerpetuEx__InvalidPosition();
    error PerpetuEx__NotOwner();
    error PerpetuEx__NoPositionChosen();
    error PerpetuEx__InvalidPositionId();
    error PerpetuEx__OpenPositionExists();
    error PerpetuEx__InsufficientLiquidity();
    error PerpetuEx__NoUserPositions();
    error PerpetuEx__NoLiquidationNeeded();

    enum PositionAction {
        Open,
        Close,
        IncreaseSize,
        DecreaseSize
    }
}
