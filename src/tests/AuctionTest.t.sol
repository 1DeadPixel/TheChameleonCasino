// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import {Test} "../../lib/forge-std/Test.sol";

contract AuctionTest is Test {

    /*
     * Bid > 
     *
     *       1 -> Test a bid with tokenRequested < than min amount.
     *       2 -> Test a bid with pricePerToken < than min amount.
     *       3 -> Test a bid when the user has a bid.
     *       4 -> Test a bid with tokenResquested > max amount.
     *       5 -> Test a bid with tokenRequested > contract balance.
     *       6 -> Test a valid bid in the round and assert that data structures are updated correctly.
     *       7 -> Test 2 valid bid inside the round and assert that the correct address is the roundwinner.
     *       8 -> Test a valid bid outside the round and assert that the bidder is the winner, that he received the tokens and that the data structures are updated correctly.
     *       9 -> Test 2 valid bids one outside and one inside the round, and assert that the previous bidder is the winner, that the new one is the current winner, and that the tokens have been sent and data structures are updated correctly.
     *      10 -> Test a cancel bid and assert that the user no longer is the current winner.
     *      11 -> Test 2 bids and assert that after the current winner gives up, the other bidder is the roundWinner.
     *      12 -> Test a cancel bid and test cleanRoundBidders.
     *      13 -> Test that we can successfully withdraw winnings.
     *      14 -> Test that we can successfully withdraw tokens.
     *      15 -> Test a complex scenario involving all of the previous tests.
     *      16 -> Deploy bby :)
     *
     *
    */

}
