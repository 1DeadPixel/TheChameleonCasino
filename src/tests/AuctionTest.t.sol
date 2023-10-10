// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import {IERC20} from "../interfaces/IERC20.sol";
import {SafeERC20} from "../utils/SafeERC20.sol";
import {Test} from "../../lib/forge-std/src/Test.sol";
import {ChameleonToken} from "../contracts/ChameleonToken.sol";
import {Auction, Round, Bidder} from "../contracts/Auction.sol";

// IN ORDER TO TEST THE AUCTION, CHANGE THE USDC_ADDRESS AND CHAMELEON_ADDRESS TO AN IMMUTABLE VARIABLE AND INITIALIZE ON CONSTRUCTOR.
// DON'T FORGET TO REVERT.
contract AuctionTest is Test {
    Auction public auction;
    ChameleonToken public usdc;
    ChameleonToken public chameleonToken;
    address public constant MAIN = address(0x512c98bEA4f87400291A03C3f91386c3fA5Dd669);
    address public constant TEST1 = address(0x21dC8c2BA087b7e66E362601c2c25c72CF023f06);
    address public constant TEST2 = address(0x31F605e38A92D67019123D7B7D1156CBcAae77da);
    address public constant TEST3 = address(0x8a750eAD041AC11987e0CE3704cF7f8B62bE4242);
    address public constant DEPLOYER = address(0xb4c79daB8f259C7Aee6E5b2Aa729821864227e84);

    using SafeERC20 for IERC20;

    /*
    * Bid > 
    *
    *       
    *      10 -> Test a cancel bid and assert that the user no longer is the current winner.
    *      11 -> Test 2 bids inside the round and assert that after the current winner gives up, the other bidder is the roundWinner.
    *      12 -> Test a cancel bid and test cleanRoundBidders.
    *      13 -> Test that the contract can successfully withdraw winnings.
    *      14 -> Test that the contract can successfully withdraw tokens.
    *      15 -> Test a complex scenario involving all of the previous tests and an auction ending.
    *
    *
    */

    function setUp() public {
        vm.startPrank(DEPLOYER);
        chameleonToken = new ChameleonToken("ChameleonToken", "CT", 100_000_000 * 10 ** 18);
        usdc = new ChameleonToken("USDC", "USDC", 1_000_000 * 10 ** 18);
        auction = new Auction(address(usdc), address(chameleonToken));
        // Transfer the cameleon tokens to the auction account and the mock USDC to the test accounts.
        chameleonToken.transfer(address(auction), 500_000 * 10 ** 18);
        assert(chameleonToken.balanceOf(address(auction)) == 500_000 * 10 ** 18);
        usdc.transfer(TEST1, 300_000 * 10 ** 18);
        usdc.transfer(TEST2, 300_000 * 10 ** 18);
        usdc.transfer(TEST3, 300_000 * 10 ** 18);
        vm.stopPrank();
        _allow(TEST1, 300_000 * 10 ** 18); // Allow auction to spend usdc.
        _allow(TEST2, 300_000 * 10 ** 18); // Allow auction to spend usdc.
        _allow(TEST3, 300_000 * 10 ** 18); // Allow auction to spend usdc.
    }

    // 1 -> Testing that a bid where the requested token amount is too low reverts.
    function testInvalidBidTokenRequestedLow() public {
        vm.prank(TEST1);
        vm.expectRevert();
        auction.bid(1 * 10 ** 15 - 1, 100000);
    }

    // 2 -> Test a bid with pricePerToken < than {minPricePerToken}.
    function testInvalidBidPricePerTokenLow() public {
        vm.prank(TEST1);
        vm.expectRevert();
        auction.bid(1 * 10 ** 15, 100);
    }

    // 3 -> Test a bid with tokenResquested > max amount.
    function testInvalidBidRequestedTooHigh() public {
        vm.prank(TEST1);
        vm.expectRevert();
        auction.bid(1_000_001 * 10 ** 18, 1000);
    }

    // 4 -> Test a bid with tokenRequested > contract balance.
    function testInvalidBidTokensRequestedHigherThanBalance() public {
        // Send
        vm.prank(TEST1);
        vm.expectRevert();
        auction.bid(500_001 * 10 ** 18, 1000);
    }

    // 5 -> Test a valid bid in the round and assert that data structures are updated correctly.
    function testValidBid() public {
        vm.prank(TEST1);
        auction.bid(1 * 10 ** 15, 1000); // Min bid
        (address bidderAddress_, uint256 tokenAmount_, uint256 pricePerToken_, uint256 amountPaid_) =
            auction.bidders(TEST1);
        assertEq(amountPaid_, 1); // amountPaid 1 USDC
        assertEq(pricePerToken_, 1000); // pricePerToken
        assertEq(bidderAddress_, TEST1); // bidderAddress
        assertEq(tokenAmount_, 1 * 10 ** 15); // tokenAmount
        (uint256 time, uint256 id, Bidder memory bidder) = auction.getRoundData();
        assert(time != 0); // roundTimestamp
        assertEq(id, 1); // currentRound
        assertEq(bidder._bidderAddress, TEST1); // Assurance that the bidder winner is being updated.
        assertEq(bidder._amountPaid, 1);
        assertEq(bidder._tokenAmount, 1 * 10 ** 15);
        assertEq(bidder._pricePerToken, 1000);
        //TODO ASSERT AUCTION . ENDED IS FALSE
        (address wBidderAddress_,,,) = auction.bidderWinner(id);
        assertEq(wBidderAddress_, address(0)); // Make sure no one is winning yet
        address[] memory roundBidders_ = auction.getRoundBidders();
        assertEq(roundBidders_[0], TEST1); // check private var being updated
    }

    // 6 -> Test a bid when the user has a bid.
    function testInvalidBidUserHasBid() public {
        vm.startPrank(TEST1);
        auction.bid(1 * 10 ** 15, 1000);
        vm.expectRevert();
        auction.bid(1 * 10 ** 15, 1000);
        vm.stopPrank();
    }

    // 7 -> Test 2 valid bid inside the round and assert that the correct address is the roundwinner.
    function testCurrentWinnerUpdating() public {
        vm.prank(TEST1);
        auction.bid(1 * 10 ** 15, 1000);
        vm.prank(TEST2);
        auction.bid(1 * 10 ** 15, 1001);
        (,, Bidder memory bidder) = auction.getRoundData();
        assertEq(bidder._bidderAddress, TEST2);
        assertEq(auction.getRoundBidders()[1], TEST2);
    }

    // 8 -> Test a valid bid outside the round and assert that the bidder is the winner, that he received the tokens and that the data structures are updated correctly.
    function testRoundWinner() public {
        vm.warp(block.timestamp + 3601);
        vm.prank(TEST1);
        auction.bid(1 * 10 ** 15, 1000);
        assert(!auction.ended());
        assert(chameleonToken.balanceOf(TEST1) == 1 * 10 ** 15);
        (uint256 timestamp, uint256 roundId, Bidder memory bidder) = auction.getRoundData();
        assert(roundId == 2);
        assert(timestamp == block.timestamp);
        assert(bidder._bidderAddress == address(0));
        (address bidderAddress_, uint256 tokenAmount_, uint256 pricePerToken_, uint256 amountPaid_) =
            auction.bidderWinner(1);
        assert(amountPaid_ == 1);
        assert(pricePerToken_ == 1000);
        assert(bidderAddress_ == TEST1);
        assert(tokenAmount_ == 1 * 10 ** 15);
        // check if bidders was cleaned
        (address bidderAddress2_,,,) = auction.bidders(TEST1);
        assert(bidderAddress2_ == address(0));
        // assert that roundBidders still has the bidder
        assert(auction.getRoundBidders()[0] == TEST1);
    }

    //  9 -> Test 2 valid bids one outside and one inside the round, and assert that the previous bidder is the winner, that the new one is the current winner, and that the tokens have been sent and data structures are updated correctly.

    function testWinAfterNewRoundBid() public {
      vm.prank(TEST1);
      auction.bid(1 * 10 ** 15, 1000);
      vm.warp(block.timestamp + 3601);
      vm.prank(TEST2);
      auction.bid(1 * 10 ** 15, 1000);
      assert(!auction.ended());
      assert(chameleonToken.balanceOf(TEST1) == 1 * 10 ** 15);
      (uint256 timestamp, uint256 roundId, Bidder memory bidder) = auction.getRoundData();
      // TODO FIX THIS
      assert(roundId == 2);
      assert(timestamp == block.timestamp);
      assert(bidder._bidderAddress == TEST2);
      (address bidderAddress_, uint256 tokenAmount_, uint256 pricePerToken_, uint256 amountPaid_) =
         auction.bidderWinner(1);
      assert(amountPaid_ == 1);
      assert(pricePerToken_ == 1000);
      assert(bidderAddress_ == TEST1);
      assert(tokenAmount_ == 1 * 10 ** 15);
      // check if bidders was cleaned
      (address bidderAddress2_,,,) = auction.bidders(TEST1);
      assert(bidderAddress2_ == address(0));
      // assert that roundBidders still has the bidder
      assert(auction.getRoundBidders()[0] == TEST1);
      assert(auction.getRoundBidders()[1] == TEST2);
    }

    // Helpers
    function _allow(address bidder_, uint256 amount) private returns (bool) {
        vm.prank(bidder_);
        usdc.increaseAllowance(address(auction), amount);
        return true;
    }
}
