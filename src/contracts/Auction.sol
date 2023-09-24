// SPDX-License-Identifier: MIT

pragma solidity ^0.8.21;

import "../interfaces/IERC20";

struct Bidder {
    address _bidder_address;
    uint256 _token_amount; 
    uint256 _staked_amount;

}

contract Auction {
    address public constant USDC_ADDRESS = address(0xaf88d065e77c8cc2239327c5edb3a432268e5831);
    
}