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
        auction.bid(1 * 10 ** 15, 999);
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
        assert(usdc.balanceOf(address(auction)) == 1);
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
        assert(usdc.balanceOf(address(auction)) == 1);
        vm.prank(TEST2);
        auction.bid(1 * 10 ** 15, 1001);
        assert(usdc.balanceOf(address(auction)) == 3);
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

    // 10 -> Test a cancel bid when a user has no bid.
    function testInvalidCancelBid() public {
        vm.prank(TEST1);
        vm.expectRevert();
        auction.cancelBid();
    }

    // 11 -> Test a cancel bid and assert that the user no longer is the current winner.
    function testCancelBid() public {
        vm.startPrank(TEST1);
        auction.bid(1 * 10 ** 15, 1000);
        auction.cancelBid();
        assert(!auction.ended());
        assert(chameleonToken.balanceOf(TEST1) == 0);
        (uint256 timestamp, uint256 roundId, Bidder memory bidder) = auction.getRoundData();
        assert(roundId == 1);
        assert(timestamp == block.timestamp);
        assert(bidder._bidderAddress == address(0));
        (address bidderAddress_, uint256 tokenAmount_, uint256 pricePerToken_, uint256 amountPaid_) =
            auction.bidderWinner(1);
        assert(amountPaid_ == 0);
        assert(pricePerToken_ == 0);
        assert(bidderAddress_ == address(0));
        assert(tokenAmount_ == 0);
        // check if bidders was cleaned
        (address bidderAddress2_,,,) = auction.bidders(TEST1);
        assert(bidderAddress2_ == address(0));
        // assert that roundBidders still has the bidder
        assert(auction.getRoundBidders()[0] == TEST1);
    }

    // 12 -> Test 2 bids inside the round and assert that after the current winner gives up, the other bidder is the roundWinner.
    function testCancelBidAndWinnerIsUpdated() public {
        vm.prank(TEST1);
        auction.bid(1 * 10 ** 15, 1000);
        vm.startPrank(TEST2);
        auction.bid(1 * 10 ** 15, 1001);
        assert(!auction.ended());
        assert(chameleonToken.balanceOf(TEST1) == 0);
        assert(chameleonToken.balanceOf(TEST2) == 0);
        (uint256 timestamp, uint256 roundId, Bidder memory bidder) = auction.getRoundData();
        assert(roundId == 1);
        assert(timestamp == block.timestamp);
        assert(bidder._bidderAddress == TEST2);
        (address bidderAddress_, uint256 tokenAmount_, uint256 pricePerToken_, uint256 amountPaid_) =
            auction.bidderWinner(1);
        assert(amountPaid_ == 0);
        assert(pricePerToken_ == 0);
        assert(bidderAddress_ == address(0));
        assert(tokenAmount_ == 0);
        (address bidderAddress2_,,,) = auction.bidders(TEST1);
        assert(bidderAddress2_ == TEST1);
        (address bidderAddress3_,,,) = auction.bidders(TEST2);
        assert(bidderAddress3_ == TEST2);
        // assert that roundBidders still has the bidder
        assert(auction.getRoundBidders()[0] == TEST1);
        assert(auction.getRoundBidders()[1] == TEST2);
        // CANCEL BID
        auction.cancelBid();
        assert(!auction.ended());
        assert(chameleonToken.balanceOf(TEST1) == 0);
        assert(chameleonToken.balanceOf(TEST2) == 0);
        (uint256 timestampC, uint256 roundIdC, Bidder memory bidderC) = auction.getRoundData();
        assert(roundIdC == 1);
        assert(timestampC == block.timestamp);
        // check if TEST1 is the current winner.
        assert(bidderC._bidderAddress == TEST1);
        (address bidderAddressC_, uint256 tokenAmountC_, uint256 pricePerTokenC_, uint256 amountPaidC_) =
            auction.bidderWinner(1);
        assert(amountPaidC_ == 0);
        assert(pricePerTokenC_ == 0);
        assert(bidderAddressC_ == address(0));
        assert(tokenAmountC_ == 0);
        // check if bidders was cleaned
        (address bidderAddressC1_,,,) = auction.bidders(TEST2);
        assert(bidderAddressC1_ == address(0));
    }

    // 13 -> Test a cancel bid and test cleanRoundBidders.
    function testCancelCleanRoundBidders() public {
        vm.prank(TEST1);
        auction.bid(1 * 10 ** 15, 1000);
        vm.startPrank(TEST2);
        auction.bid(1 * 10 ** 15, 1002);
        auction.cancelBid();
        (uint256 timestampC, uint256 roundIdC, Bidder memory bidderC) = auction.getRoundData();
        assert(roundIdC == 1);
        assert(timestampC == block.timestamp);
        // check if TEST1 is the current winner.
        assert(bidderC._bidderAddress == TEST1);
        vm.stopPrank();
        vm.prank(TEST1);
        auction.cancelBid();
        (uint256 timestampC1, uint256 roundIdC1, Bidder memory bidderC1) = auction.getRoundData();
        assert(roundIdC1 == 1);
        assert(timestampC1 == block.timestamp);
        // check if noone is winner.
        assert(bidderC1._bidderAddress == address(0));
        // check if addresses are still on the roundBiders.
        assert(auction.getRoundBidders()[0] == TEST1);
        assert(auction.getRoundBidders()[1] == TEST2);
        // assert that only owner can clean round bidders
        vm.prank(TEST1);
        vm.expectRevert();
        auction.cleanRoundBidders();
        vm.prank(DEPLOYER);
        auction.cleanRoundBidders();
        assert(auction.getRoundBidders().length == 0);
    }

    // 13 -> Test that the contract can successfully withdraw winnings.
    function testWhithdrawWinnings() public {
        vm.prank(TEST1);
        auction.bid(1 * 10 ** 15, 1000);
        vm.warp(block.timestamp + 3601);
        vm.prank(TEST2);
        auction.bid(1*10**15, 1000);
        assert(chameleonToken.balanceOf(TEST1) == 1 * 10 ** 15);
        vm.warp(block.timestamp + 3601);
        vm.prank(TEST3);
        auction.bid(1 * 10 ** 15, 1000);
        assert(chameleonToken.balanceOf(TEST2) == 1 * 10 ** 15);
        assert(usdc.balanceOf(address(auction)) == 3);
        (uint256 timestamp, uint256 roundId, Bidder memory bidder) = auction.getRoundData();
        assert(roundId == 3);
        assert(timestamp == block.timestamp);
        assert(bidder._bidderAddress == TEST3);
        (address bidderAddress1_,,,) = auction.bidders(TEST1);
        assert(bidderAddress1_ == address(0));
        (address bidderAddress2_,,,) = auction.bidders(TEST2);
        assert(bidderAddress2_ == address(0));
        (address bidderAddress3_,,,) = auction.bidders(TEST3);
        assert(bidderAddress3_ == TEST3);
        // assert that only owner can withdraw winnigns
        vm.prank(TEST1);
        vm.expectRevert();
        auction.withdrawWinnerBids();
        // assert that the owner can withdraw winnings
        (address bidderAddressW1_, uint256 tokenAmountW1_, uint256 pricePerTokenW1_, uint256 amountPaidW1_) =
            auction.bidderWinner(1);
        assert(amountPaidW1_ == 1);
        assert(bidderAddressW1_ == TEST1);
        assert(pricePerTokenW1_ == 1000);
        assert(tokenAmountW1_ == 1 * 10 ** 15);
        (address bidderAddressW2_, uint256 tokenAmountW2_, uint256 pricePerTokenW2_, uint256 amountPaidW2_) =
            auction.bidderWinner(2);
        assert(amountPaidW2_ == 1);
        assert(bidderAddressW2_ == TEST2);
        assert(pricePerTokenW2_ == 1000);
        assert(tokenAmountW2_ == 1 * 10 ** 15);
        assert(auction.getClaimedBids() == 0);
        (, uint256 roundId2,) = auction.getRoundData();
        assert(roundId2 == 3);
        vm.prank(DEPLOYER);
        auction.withdrawWinnerBids();
        assert(usdc.balanceOf(DEPLOYER) == 100000 * 10 ** 18 + 2);
        assert(auction.getClaimedBids() == 2);
        // Test withdrawing round 3 winnings but as the round hasn't ended the balance stays the same.
        vm.prank(DEPLOYER);
        auction.withdrawWinnerBids();
        assert(usdc.balanceOf(DEPLOYER) == 100000 * 10 ** 18 + 2);
        assert(auction.getClaimedBids() == 2);
    }

    // 14 -> Test that the contract can successfully withdraw tokens.
    function testWithdrawChameleonTokens() public {
        // Assert that only owner can withdraw
        vm.prank(TEST1);
        vm.expectRevert();
        auction.withdrawTokens(1);
        // Assert owner cannot withdraw more than the casino balance
        vm.prank(DEPLOYER);
        vm.expectRevert();
        auction.withdrawTokens(500001 * 10 ** 18);
        // Assert the owner can withdraw tokens
        vm.prank(DEPLOYER);
        auction.withdrawTokens(500_000 * 10 ** 18);
        assert(chameleonToken.balanceOf(DEPLOYER) == 100_000_000 * 10 ** 18);
    }

    // 15 -> Test a complex scenario involving all of the previous tests and an auction ending.
    function testAll() public {
        vm.prank(TEST1);
        auction.bid(1 * 10 ** 18, 1000);
        vm.prank(TEST2);
        auction.bid(100_000 * 10 ** 18, 10000);
        (,, Bidder memory bidder) = auction.getRoundData();
        assert(bidder._bidderAddress == TEST2);
        vm.warp(block.timestamp + 3601);
        vm.prank(TEST1);
        vm.expectRevert();
        auction.bid(1 * 10 ** 15, 1000);
        vm.prank(TEST3);
        auction.bid(1 * 10 ** 18, 1000);
        assert(chameleonToken.balanceOf(TEST2) == 100_000 * 10 ** 18);
        (,, Bidder memory bidder2) = auction.getRoundData();
        // because TEST3 bidded the same as TEST1
        assert(bidder2._bidderAddress == TEST1);
        vm.warp(block.timestamp + 3601);
        vm.prank(TEST2);
        auction.bid(100_000 * 10 ** 18, 1001);
        assert(chameleonToken.balanceOf(TEST1) == 1 * 10 ** 18);
        (,, Bidder memory bidder3) = auction.getRoundData();
        assert(bidder3._bidderAddress == TEST2);
        vm.prank(TEST3);
        vm.expectRevert();
        auction.bid(1 * 10 ** 15, 10000);
        vm.warp(block.timestamp + 3601);
        vm.prank(TEST1);
        auction.bid(1 * 10 ** 18, 2000);
        assert(chameleonToken.balanceOf(TEST2) == 200_000 * 10 ** 18);
        vm.prank(TEST2);
        vm.warp(block.timestamp + 3601);
        auction.bid(100_000 * 10 ** 18, 1001);
        assert(chameleonToken.balanceOf(TEST1) == 2 * 10 ** 18);
        (,, Bidder memory bidder4) = auction.getRoundData();
        assert(bidder4._bidderAddress == TEST2);
        vm.warp(block.timestamp + 3601);
        vm.prank(TEST1);
        auction.bid(1 * 10 ** 18, 1000);
        (,, Bidder memory bidder5) = auction.getRoundData();
        assert(bidder5._bidderAddress == TEST3);
        assert(chameleonToken.balanceOf(TEST2) == 300_000 * 10 ** 18);
        vm.warp(block.timestamp + 3601);
        assert(chameleonToken.balanceOf(TEST3) == 0);
        vm.prank(TEST2);
        auction.bid(100_000 * 10 ** 18, 1005);
        assert(chameleonToken.balanceOf(TEST3) == 1* 10 ** 18);
        (,, Bidder memory bidder6) = auction.getRoundData();
        assert(bidder6._bidderAddress == TEST2);
        vm.warp(block.timestamp + 3601);
        vm.prank(TEST3);
        auction.bid(1*10**18, 1000);
        (,, Bidder memory bidder7) = auction.getRoundData();
        assert(bidder7._bidderAddress == TEST1);
        assert(chameleonToken.balanceOf(TEST2) == 400_000 * 10 ** 18);
        vm.warp(block.timestamp + 3601);
        vm.startPrank(TEST2);
        vm.expectRevert();
        // No longer has 100k tokens
        auction.bid(100_000 * 10 ** 18, 2000);
        auction.bid(99997 * 10 ** 18, 2000);
        assert(chameleonToken.balanceOf(TEST1) == 3 * 10 ** 18);
        assert(chameleonToken.balanceOf(TEST3) == 1 * 10 ** 18);
        vm.warp(block.timestamp + 3601);
        vm.stopPrank();
        vm.prank(TEST1);
        auction.bid(1 * 10 **18, 1000);
        // When he betted 999997, there were only 999996
        assert(chameleonToken.balanceOf(TEST2) == 499996 * 10 ** 18);
        assert(chameleonToken.balanceOf(address(auction)) == 0);
        assert(auction.ended());
        vm.prank(TEST2);
        vm.expectRevert();
        // Auction has ended.
        auction.bid(1 * 10 ** 18, 1000);
        // Didn't get the tokens but the money back
        assert(chameleonToken.balanceOf(TEST1) == 3 * 10 ** 18);
    }
    

    // Helpers
    function _allow(address bidder_, uint256 amount) private returns (bool) {
        vm.prank(bidder_);
        usdc.increaseAllowance(address(auction), amount);
        return true;
    }
}
