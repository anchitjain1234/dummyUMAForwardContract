// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol";
import "hardhat/console.sol";

contract SyntheticToken is ERC20 {
    constructor(string memory _tokenName, string memory _tokenSymbol) ERC20(_tokenName, _tokenSymbol) {
    }

    function decimals() public view virtual override returns (uint8) {
        return 0;
    }

    //TODO: Add modifier for permissions.
    function mint(address _recipient, uint256 _amount) public {
        _mint(_recipient, _amount);
    }

    //TODO: Add modifier for permissions.
    function burn(uint256 _amount) public {
        _burn(msg.sender, _amount);
    }
}