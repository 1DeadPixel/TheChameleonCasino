// SPDX-License-Identifier: MIT

pragma solidity ^0.8.21;

import {IERC20} from "../interfaces/IERC20.sol"; 
import {SafeERC20} from "../utils/SafeERC20.sol";


struct Bidder {
    address _bidderAddress;
    uint256 _tokenAmount; 
    uint256 _pricePerToken;
}

error InvalidStart();

contract Auction {
    using SafeERC20 for IERC20;


    uint256 public constant MINIMUM_STAKE_PER_TOKEN = 1000;
    uint256 public constant MAX_TOKENS_PER_ROUND = 1_000000_000000000000000000;
    address public constant USDC_ADDRESS = address(0xaf88d065e77c8cC2239327C5EDb3A432268e5831);

    uint256 private constant _HOUR = 3600;

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
     * -> Bidder Address cannot be 0.
     * -> Bidder cannot have a placed bid. It must cancel it first.
     * -> {requestedAmount} cannot be bigger than {MAX_TOKENS_PER_ROUND}.
     * -> {pricePerToken} >= {MINIMUM_STAKE_PER_TOKEN}.
     * -> This contract Chameleon Token balance must be equal or bigger than the requested amount.
     * 
     * Will trigger a new round if {now} > {roundTimestamp} + _HOUR,
     * but only after the current bidder has been taken in consideration, allowing an address to win a round if it bids in a round that has ended but there are no bidders.
     *
    */
    function bid(address bidder_, uint256 requestedAmount_, uint256 pricePerToken_) public returns (bool) {
        bool isNewRound_ = _isNewRound(block.timestamp); 
        if (isNewRound_ && roundCurrentWinner != Bidder()) {_triggerNewRound();}
        // do stuff
        if (isNewRound_) {_triggerNewRound();}
    }

    // Checks if it's time for a new round.
    function _isNewRound(uint256 timestamp_) private view returns(bool) {
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
        // Reset structures.
        currentRound += 1;
        roundCurrentWinner = Bidder();
        roundTimestamp = block.timestamp;
        // The round winner is always placed on the position 0.
        delete _roundBidders[0];
        
        _updateRoundCurrentWinner();

    }

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