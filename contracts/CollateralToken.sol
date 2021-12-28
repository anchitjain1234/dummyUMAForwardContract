// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol";
import "hardhat/console.sol";

contract CollateralToken is ERC20 {
    constructor() ERC20("MyETH", "mETH") {
        _mint(msg.sender, 1000000);
    }

    function decimals() public view virtual override returns (uint8) {
        return 0;
    }
}