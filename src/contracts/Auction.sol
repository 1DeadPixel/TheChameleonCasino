// SPDX-License-Identifier: MIT

pragma solidity ^0.8.21;

import {Math} from "../lib/Math.sol";
import {ERC20} from "../contracts/ERC20.sol";
import {IERC20} from "../interfaces/IERC20.sol";
import {SafeERC20} from "../utils/SafeERC20.sol";

struct Bidder {
    address _bidderAddress;
    uint256 _tokenAmount;
    uint256 _pricePerToken;
}

error NoBid();
error LowBid();
error BidExists();
error InvalidStart();
error BidderIs0Address();
error ExceedsMaxPerRound();
error InsufficientBalance();

contract Auction {
    using Math for uint256;
    using SafeERC20 for IERC20;

    uint256 public constant MINIMUM_PRICE_PER_TOKEN = 1000;
    uint256 public constant MINIMUM_TOKEN_AMOUNT = 1 * 10 ** 15;
    uint256 public constant MAX_TOKENS_PER_ROUND = 1_000_000 * 10 ** 18;
    address public constant USDC_ADDRESS = address(0xaf88d065e77c8cC2239327C5EDb3A432268e5831);
    address public constant CHAMELEON_ADDRESS = address(0x14BC09B277Eea6E14B5EEDD275D404FC07F0C4E4);

    uint256 private constant _HOUR = 3600;

    // TODO: Turn this into a struct and create getRoundData.
    uint256 public roundTimestamp;
    uint256 public currentRound = 1;
    Bidder public roundCurrentWinner;

    // Needed to update roundCurrentWinner when the {currentWinner} gives up before the round ends or a new round beggins.
    address[] private _roundBidders;
    mapping(uint256 _roundId => Bidder) public bidderWinner;
    mapping(address _bidder => Bidder _bidderData) public bidders;

    constructor() {
        roundTimestamp = block.timestamp;
    }

    /* Bids in the current round. Triggers a new round if the timestamp is correspondent to the start of another round.
     *
     * Requirements:
     *
     * -> Bidder cannot have a placed bid. It must cancel it first.
     * -> {requestedAmount} <= {MAX_TOKENS_PER_ROUND}.
     * -> {pricePerToken} >= {MINIMUM_PRICE_PER_TOKEN}
     * -> {requestedAmount} >= {MINIMUM_TOKEN_AMOUNT}.
     * -> This contract Chameleon Token balance must be equal or bigger than the requested amount.
     * 
     * Will trigger a new round if {now} > {roundTimestamp} + _HOUR,
     * but only after the current bidder has been taken in consideration, allowing an address to win a round if it bids in a round that has ended but there are no bidders.
     *
    */
    function bid(uint256 requestedAmount_, uint256 pricePerToken_) public returns (bool) {
        address bidder_ = msg.sender;
        bool isNewRound_ = _isNewRound(block.timestamp);

        if (isNewRound_ && roundCurrentWinner._bidderAddress != address(0)) _triggerNewRound();
        _validateBid(bidder_, requestedAmount_, pricePerToken_);

        SafeERC20.safeTransferFrom(
            IERC20(USDC_ADDRESS), bidder_, address(this), _computePrice(requestedAmount_, pricePerToken_)
        );
        _addBider(bidder_, requestedAmount_, pricePerToken_);
        if (isNewRound_) _triggerNewRound();

        return true;
    }

    /*
     * Cancels an address bid.
     *
     * Does not trigger a new round.
     * 
     * Requirements:
     * 
     * -> Address must have a bid.
     *
    */
    function cancelBid() public returns (bool) {
        address sender = msg.sender;
        Bidder memory bidder = bidders[sender];

        if (bidder._bidderAddress != sender) {
            revert NoBid();
        }

        uint256 bidderAmount = _computePrice(bidder._tokenAmount, bidder._pricePerToken);
        delete bidders[sender];
        SafeERC20.safeTransfer(IERC20(USDC_ADDRESS), sender, bidderAmount);
        return true;
    }

    function _computePrice(uint256 requestedAmount_, uint256 pricePerToken_) private pure returns (uint256) {
        return requestedAmount_.mulDiv(pricePerToken_, 10 ** 18, Math.Rounding.Up);
    }

    function _addBider(address bidder_, uint256 requestedAmount_, uint256 pricePerToken_) private {
        Bidder memory newBidder_ = Bidder(bidder_, requestedAmount_, pricePerToken_);
        bidders[bidder_] = newBidder_;
        if (newBidder_._pricePerToken > roundCurrentWinner._pricePerToken) {
            roundCurrentWinner = newBidder_;
        }
        _roundBidders.push(bidder_);
    }

    /*
     * Checks if the placed bid is valid.
     *
     * Check bid() function to see the requirements.
    */
    function _validateBid(address bidder_, uint256 requestedAmount_, uint256 pricePerToken_) private view {
        if (requestedAmount_ < MINIMUM_TOKEN_AMOUNT) revert LowBid();
        if (pricePerToken_ < MINIMUM_PRICE_PER_TOKEN) revert LowBid();
        if (bidders[bidder_]._bidderAddress != address(0)) revert BidExists();
        if (requestedAmount_ > MAX_TOKENS_PER_ROUND) revert ExceedsMaxPerRound();
        if (IERC20(CHAMELEON_ADDRESS).balanceOf(address(this)) < requestedAmount_) revert InsufficientBalance();
    }

    // Checks if it's time for a new round.
    function _isNewRound(uint256 timestamp_) private view returns (bool) {
        return timestamp_ > roundTimestamp + _HOUR;
    }

    /*
     * Triggers a new round, indexing the round winner of the previous round.
     * The winning address now has the option to claim the tokens of the winning bid.
     * 
     * This function is only called by bid, when a new round starts, so all requirements have been checked.
     *
    */
    function _triggerNewRound() private {
        bidderWinner[currentRound] = roundCurrentWinner;
        // Update structures and variables.
        currentRound += 1;
        Bidder memory emptyBidder_;
        roundCurrentWinner = emptyBidder_;
        roundTimestamp = block.timestamp;

        delete bidders[bidderWinner[currentRound-1]._bidderAddress];

        _updateRoundCurrentWinner();

        SafeERC20.safeTransfer(
            IERC20(CHAMELEON_ADDRESS),
            bidderWinner[currentRound - 1]._bidderAddress,
            bidderWinner[currentRound - 1]._tokenAmount
        );
    }

    // Updates the current highest bidder.
    function _updateRoundCurrentWinner() private {
        address maxBidder_ = _roundBidders[0];
        for (uint256 i = 1; i < _roundBidders.length; i++) {
            if (bidders[_roundBidders[i]]._pricePerToken > bidders[maxBidder_]._pricePerToken) {
                maxBidder_ = _roundBidders[i];
            }
        }
        roundCurrentWinner = bidders[maxBidder_];
    }
}
