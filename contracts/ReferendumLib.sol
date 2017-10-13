pragma solidity ^0.4.9;

import "./SafeMathLib.sol";
import "./Storage.sol";

// A Referendum represents a vote being held on a single matter
// Voters are identified by address 
// Each voter can vote at most once on a Referendum
// The Referendum starts in the Undecided state
// While it is Undecided votes may be cast using the vote function
// While it is Undecided tryDecide may be called to attempt to 'decide' the referendum
// There are three conditions for deciding a referendum:
// - If the number of YES votes exceeds a given percentage (T) of a given number (P) then the Referendum is Accepted
// - else if the number of NO votes exceeds a given percentage (T) of a given number (P) then the Referendum is Rejected
// - else if the Referendum's ExpiryTime has passed then 
//   - If there are more YES than NO votes then the proposal is Accepted, 
//   - Else it is Rejected
// In practice, T is the parameter 'PRM_VOTE_DECIDE_THRESHOLD_PERCENT' and P is the total population of account voters.
// All data is stored in a Storage
library ReferendumLib {

    using SafeMathLib for uint;

    bytes32 constant public F_IS_EXISTENT = sha3("F_REFERENDUM_IS_EXISTENT");
    bytes32 constant public F_STATE = sha3("F_REFERENDUM_STATE");
    bytes32 constant public F_HAS_VOTED = sha3("F_REFERENDUM_HAS_VOTED");
    bytes32 constant public F_EXPIRY_TIME = sha3("F_REFERENDUM_EXPIRY_TIME");
    bytes32 constant public F_VOTE_COUNT_YES = sha3("F_REFERENDUM_VOTE_COUNT_YES");
    bytes32 constant public F_VOTE_COUNT_NO = sha3("F_REFERENDUM_VOTE_COUNT_NO");

    uint constant public E_REFERENDUM_STATE_UNDECIDED = 0;
    uint constant public E_REFERENDUM_STATE_ACCEPTED = 1;
    uint constant public E_REFERENDUM_STATE_REJECTED = 2;

    function init(Storage self, uint id, uint timeToLive) public {

        self.setBool(F_IS_EXISTENT, id, true);
        self.setUInt(F_EXPIRY_TIME, id, now.plus(timeToLive));
    }

    // Cast a YES or NO vote on the Referendum
    // Throws if the Referendum is decided
    // Throws if user has already voted
    // Otherwise just records the vote
    function vote(Storage self, uint id, address voter, bool isYes) public {
        require(self.getBool(F_IS_EXISTENT, id));

        var hasVotedKey = keccak256(voter, id);

        require(!self.getBool(F_HAS_VOTED, hasVotedKey));
        require(self.getUInt(F_STATE, id) == E_REFERENDUM_STATE_UNDECIDED);

        self.setBool(F_HAS_VOTED, hasVotedKey, true);

        if (isYes) {
            self.setUInt(F_VOTE_COUNT_YES, id, self.getUInt(F_VOTE_COUNT_YES, id).plus(1));
        } else {
            self.setUInt(F_VOTE_COUNT_NO, id, self.getUInt(F_VOTE_COUNT_NO, id).plus(1));
        }
    }

    // If a Referendum is in state Undecided you can call tryDecide
    // If the required conditions are met, the Referendum will move into the Accepted or Rjected state accordingly
    // Else the Referendum will remain in the Undecided state
    // True is returned if the state transitioned from Undecided to Accepted
    function tryDecide(Storage self, uint id, uint voterCount, uint thresholdPercent) public returns(bool) {
        require(self.getBool(F_IS_EXISTENT, id));
        require(self.getUInt(F_STATE, id) == E_REFERENDUM_STATE_UNDECIDED);

        var voteCountYes = self.getUInt(F_VOTE_COUNT_YES, id);
        var voteCountNo = self.getUInt(F_VOTE_COUNT_NO, id);

        var percentYes = ((voteCountYes.times(100)) / voterCount);
        var percentNo = ((voteCountNo.times(100)) / voterCount);        

        if (percentYes >= thresholdPercent) {
            self.setUInt(F_STATE, id, E_REFERENDUM_STATE_ACCEPTED);            
        } else if (percentNo >= thresholdPercent) {
            self.setUInt(F_STATE, id, E_REFERENDUM_STATE_REJECTED); 
        } else if (now > self.getUInt(F_EXPIRY_TIME, id)) {
            if (voteCountYes > voteCountNo) {
                self.setUInt(F_STATE, id, E_REFERENDUM_STATE_ACCEPTED);
            } else {
                self.setUInt(F_STATE, id, E_REFERENDUM_STATE_REJECTED); 
            }
        }

        return self.getUInt(F_STATE, id) == E_REFERENDUM_STATE_ACCEPTED;
    }

    function hasVoted(Storage self, uint id, address voter) public constant returns(bool) {
        var hasVotedKey = keccak256(voter, id);
        return self.getBool(F_HAS_VOTED, hasVotedKey);
    }

    function get(Storage self, uint id) public constant returns(bool isExistent, uint state, uint expiryTime, uint voteCountYes, uint voteCountNo) {
        isExistent = self.getBool(F_IS_EXISTENT, id);
        state = self.getUInt(F_STATE, id);
        expiryTime = self.getUInt(F_EXPIRY_TIME, id);
        voteCountYes = self.getUInt(F_VOTE_COUNT_YES, id);
        voteCountNo = self.getUInt(F_VOTE_COUNT_NO, id);
        return;
    }    
}