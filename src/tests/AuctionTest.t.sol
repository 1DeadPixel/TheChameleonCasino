// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import {IERC20} from "../interfaces/IERC20.sol";
import {SafeERC20} from "../utils/SafeERC20.sol";
import {Auction} from "../contracts/Auction.sol";
import {Test} from "../../lib/forge-std/src/Test.sol";
import {ChameleonToken} from "../contracts/ChameleonToken.sol";


// IN ORDER TO TEST THE AUCTION, CHANGE THE USDC_ADDRESS TO AN IMMUTABLE VARIABLE AND INITIALIZE ON CONSTRUCTOR.
// DON'T FORGET TO REVERT.
contract AuctionTest is Test {
    Auction public auction;
    address public constant MAIN = address(0x512c98bEA4f87400291A03C3f91386c3fA5Dd669);
    address public constant TEST1 = address(0x21dC8c2BA087b7e66E362601c2c25c72CF023f06);
    address public constant TEST2 = address(0x31F605e38A92D67019123D7B7D1156CBcAae77da);
    address public constant TEST3 = address(0x8a750eAD041AC11987e0CE3704cF7f8B62bE4242);
    address public constant DEPLOYER = address(0xb4c79daB8f259C7Aee6E5b2Aa729821864227e84);

    using SafeERC20 for IERC20;
    
    /*
     * Bid > 
     *
     *       6 -> Test a valid bid in the round and assert that data structures are updated correctly.
     *       7 -> Test 2 valid bid inside the round and assert that the correct address is the roundwinner.
     *       8 -> Test a valid bid outside the round and assert that the bidder is the winner, that he received the tokens and that the data structures are updated correctly.
     *       9 -> Test 2 valid bids one outside and one inside the round, and assert that the previous bidder is the winner, that the new one is the current winner, and that the tokens have been sent and data structures are updated correctly.
     *      10 -> Test a cancel bid and assert that the user no longer is the current winner.
     *      11 -> Test 2 bids and assert that after the current winner gives up, the other bidder is the roundWinner.
     *      12 -> Test a cancel bid and test cleanRoundBidders.
     *      13 -> Test that we can successfully withdraw winnings.
     *      14 -> Test that we can successfully withdraw tokens.
     *      15 -> Test a complex scenario involving all of the previous tests and an auction ending.
     *
     *
    */

   function setUp() public {
      vm.startPrank(DEPLOYER);
      IERC20 USDC = new ChameleonToken("USDC", "USDC", 1_000 * 10 ** 18);
      IERC20 chameleonToken = new ChameleonToken("ChameleonToken", "CT", 100_000_000 * 10 ** 18);
      auction = new Auction(address(USDC));
      // Transfer the cameleon tokens to the auction account and the mock USDC to the test accounts.
      chameleonToken.transfer(address(auction), 500_000 *10 **18);
      USDC.transfer(TEST1, 300 * 10 ** 18);
      USDC.transfer(TEST2, 300 * 10 ** 18);
      USDC.transfer(TEST3, 300 * 10 ** 18);
      vm.stopPrank();
     }

   // 1 -> Testing that a bid where the requested token amount is too low reverts.
   function test_invalid_bid_token_requested_low() public {
        vm.prank(TEST1);
        vm.expectRevert();
        auction.bid(1*10**15-1, 100000);
     }
   
   // 2 -> Test a bid with pricePerToken < than {minPricePerToken}.
   function test_invalid_bid_price_per_token_low() public {
      vm.prank(TEST1);
      vm.expectRevert();
      auction.bid(1*10**15, 100);
   }

   // 3 -> Test a bid with tokenResquested > max amount.
   function test_invalid_bid_requested_too_high() public {
      vm.prank(TEST1);
      vm.expectRevert();
      auction.bid(1_000_001 * 10 ** 18, 1000);
   }

   // 4 -> Test a bid with tokenRequested > contract balance.
   function test_invalid_bid_tokens_requested_higher_than_balance() public {
      // Send 
      vm.prank(TEST1);
      vm.expectRevert();
      auction.bid(requestedAmount_, pricePerToken_);
   }
   
   //  -> Test a bid when the user has a bid.
   
}