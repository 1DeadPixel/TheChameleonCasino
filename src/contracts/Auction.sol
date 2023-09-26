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
    uint256 _amountPaid;
}

struct Round {
    uint256 _roundTimestamp;
    uint256 _currentRound;
    Bidder _roundCurrentWinner;
}

error NoBid();
error LowBid();
error NotOwner();
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
    address public constant USDC_ADDRESS =
        address(0xaf88d065e77c8cC2239327C5EDb3A432268e5831);
    address public constant CHAMELEON_ADDRESS =
        address(0x14BC09B277Eea6E14B5EEDD275D404FC07F0C4E4);

    uint256 private _claimedBids;
    address private immutable _owner;
    uint256 private constant _HOUR = 3600;

    // TODO: Turn this into a struct and create getRoundData.
    Round public getRoundData;

    // Needed to update roundCurrentWinner when the {currentWinner} gives up before the round ends or a new round beggins.
    address[] private _roundBidders;
    mapping(uint256 _roundId => Bidder) public bidderWinner;
    mapping(address _bidder => Bidder _bidderData) public bidders;

    constructor() {
        _owner = msg.sender;
        getRoundData._currentRound = 1;
        getRoundData._roundTimestamp = block.timestamp;
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
    function bid(
        uint256 requestedAmount_,
        uint256 pricePerToken_
    ) public returns (bool) {
        address bidder_ = msg.sender;
        bool isNewRound_ = _isNewRound(block.timestamp);

        if (
            isNewRound_ &&
            getRoundData._roundCurrentWinner._bidderAddress != address(0)
        ) _triggerNewRound();
        _validateBid(bidder_, requestedAmount_, pricePerToken_);

        uint256 amountToPay_ = _computePrice(requestedAmount_, pricePerToken_);

        SafeERC20.safeTransferFrom(
            IERC20(USDC_ADDRESS),
            bidder_,
            address(this),
            amountToPay_
        );
        _addBider(bidder_, requestedAmount_, pricePerToken_, amountToPay_);
        if (isNewRound_) _triggerNewRound();

        return true;
    }

    /*
     * Cancels an address bid.
     *
     * Does not trigger a new round. Will update the new round winner.
     *
     * Requirements:
     *
     * -> Address must have a bid.
     *
     */
    function cancelBid() public returns (bool) {
        address sender = msg.sender;
        Bidder memory bidder = bidders[sender];

        if (bidder._bidderAddress == address(0)) {
            revert NoBid();
        }

        uint256 bidderAmount = bidder._amountPaid;

        delete bidders[sender];

        // Check if bidder was the winner and update the winner if it was.
        if (getRoundData._roundCurrentWinner._bidderAddress == sender) {
            _updateRoundCurrentWinner();
        }

        SafeERC20.safeTransfer(IERC20(USDC_ADDRESS), sender, bidderAmount);
        return true;
    }

    function _computePrice(
        uint256 requestedAmount_,
        uint256 pricePerToken_
    ) private pure returns (uint256) {
        return
            requestedAmount_.mulDiv(pricePerToken_, 10 ** 18, Math.Rounding.Up);
    }

    function _addBider(
        address bidder_,
        uint256 requestedAmount_,
        uint256 pricePerToken_,
        uint256 amountPaid_
    ) private {
        Bidder memory newBidder_ = Bidder(
            bidder_,
            requestedAmount_,
            pricePerToken_,
            amountPaid_
        );
        bidders[bidder_] = newBidder_;
        if (
            newBidder_._pricePerToken >
            getRoundData._roundCurrentWinner._pricePerToken
        ) {
            getRoundData._roundCurrentWinner = newBidder_;
        }
        _roundBidders.push(bidder_);
    }

    /*
     * Checks if the placed bid is valid.
     *
     * Check bid() function to see the requirements.
     */
    function _validateBid(
        address bidder_,
        uint256 requestedAmount_,
        uint256 pricePerToken_
    ) private view {
        if (requestedAmount_ < MINIMUM_TOKEN_AMOUNT) revert LowBid();
        if (pricePerToken_ < MINIMUM_PRICE_PER_TOKEN) revert LowBid();
        if (bidders[bidder_]._bidderAddress != address(0)) revert BidExists();
        if (requestedAmount_ > MAX_TOKENS_PER_ROUND)
            revert ExceedsMaxPerRound();
        if (
            IERC20(CHAMELEON_ADDRESS).balanceOf(address(this)) <
            requestedAmount_
        ) revert InsufficientBalance();
    }

    // Checks if it's time for a new round.
    function _isNewRound(uint256 timestamp_) private view returns (bool) {
        return timestamp_ > getRoundData._roundTimestamp + _HOUR;
    }

    /*
     * Triggers a new round, indexing the round winner of the previous round.
     * The winning address now has the option to claim the tokens of the winning bid.
     *
     * This function is only called by bid, when a new round starts, so all requirements have been checked.
     *
     */
    function _triggerNewRound() private {
        bidderWinner[getRoundData._currentRound] = getRoundData
            ._roundCurrentWinner;
        // Update structures and variables.
        getRoundData._currentRound += 1;
        Bidder memory emptyBidder_;
        getRoundData._roundCurrentWinner = emptyBidder_;
        getRoundData._roundTimestamp = block.timestamp;

        delete bidders[
            bidderWinner[getRoundData._currentRound - 1]._bidderAddress
        ];

        _updateRoundCurrentWinner();

        SafeERC20.safeTransfer(
            IERC20(CHAMELEON_ADDRESS),
            bidderWinner[getRoundData._currentRound - 1]._bidderAddress,
            bidderWinner[getRoundData._currentRound - 1]._tokenAmount
        );
    }

    // Updates the current highest bidder.
    function _updateRoundCurrentWinner() private {
        address maxBidder_;
        for (uint256 i = 0; i < _roundBidders.length; i++) {
            address bidder_ = _roundBidders[i];
            if (
                bidders[bidder_]._pricePerToken >
                getRoundData._roundCurrentWinner._pricePerToken
            ) {
                maxBidder_ = bidder_;
            }
        }
        getRoundData._roundCurrentWinner = bidders[maxBidder_];
    }

    // In case _roundBidders gets too big.
    function cleanRoundBidders() public isOwner {
        uint256 counter = 0;
        address[] memory haveBids;
        for (uint256 i = 0; i < _roundBidders.length; i++) {
            address bidderAddress_ = _roundBidders[i];
            if (bidders[bidderAddress_]._bidderAddress != address(0)) {
                haveBids[counter] = bidderAddress_;
                counter++;
            }
        }
        _roundBidders = haveBids;
    }

    // Withraw all winning bids up to the current round, that haven't been withdrawn yet
    function withdrawWinnerBids() public isOwner returns (bool) {
        uint256 amountToClaim_;
        for (
            uint256 i = _claimedBids + 1;
            i < getRoundData._currentRound;
            i++
        ) {
            amountToClaim_ += bidderWinner[i]._amountPaid;
        }
        _claimedBids = getRoundData._currentRound - 1;
        SafeERC20.safeTransfer(IERC20(USDC_ADDRESS), _owner, amountToClaim_);
        return true;
    }

    // Withdraws Chameleon Tokens from the vault.
    function withdrawTokens(uint256 amount) public isOwner returns (bool) {
        IERC20 chameleonToken = IERC20(CHAMELEON_ADDRESS);
        SafeERC20.safeTransfer(chameleonToken, _owner, amount);
        return true;
    }

    modifier isOwner() {
        if (msg.sender != _owner) {
            revert NotOwner();
        }
        _;
    }
}
