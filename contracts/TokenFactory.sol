// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "./SyntheticToken.sol";

contract TokenFactory {
    function createToken(string memory _tokenName, string memory _tokenSymbol) public returns (SyntheticToken) {
        return new SyntheticToken(_tokenName, _tokenSymbol);
    }
}