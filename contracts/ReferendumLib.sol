pragma solidity ^0.4.9;

import "./SafeMathLib.sol";

// A Referendum represents a vote being held on a single matter
// Voters are identified by address 
// Each voter can vote at most once on a Referendum
// The Referendum starts in the Undecided state
// While it is Undecided votes may be cast using the vote function
// While it is Undecided tryDecide may be called to attempt to 'decide' the referendum
// There are three conditions for deciding a referendum:
// - If the number of YES votes exceeds a given percentage (T) of a given number (P) then the Referendum is Accepted
// - If the number of NO votes exceeds a given percentage (T) of a given number (P) then the Referendum is Rejected
// - If the Referendum's ExpiryTime has passed the the Referendum is Expired
// In practice, T is the parameter 'voteDecideThresholdPercent' and P is the total population of account holders.
library ReferendumLib {

    using SafeMathLib for uint;

    struct Referendum {
        bool isExistent;
        ReferendumState state;
        mapping(address=>bool) hasVoted;
        uint expiryTime;
        uint voteCountYes;
        uint voteCountNo;
    }

    enum ReferendumState {
        Undecided,
        Accepted,
        Rejected,
        Expired
    }

    function init(Referendum storage self, uint timeToLive) public {
        self.isExistent = true;
        self.expiryTime = now.plus(timeToLive);
    }

    // Cast a YES or NO vote on the Referendum
    // Throws if the Referendum is decided
    // Throws if user has already voted
    // Otherwise just records the vote
    function vote(Referendum storage self, address voter, bool isYes) public {
        require(self.isExistent);
        require(!self.hasVoted[voter]);
        require(self.state == ReferendumState.Undecided);

        self.hasVoted[voter] = true;

        if (isYes) {
            self.voteCountYes = self.voteCountYes.plus(1);
        } else {
            self.voteCountNo = self.voteCountNo.plus(1);
        }
    }

    function tryDecide(Referendum storage self, uint voterCount, uint thresholdPercent) public returns(ReferendumState) {
        require(self.isExistent);
        require(self.state == ReferendumState.Undecided);

        var percentYes = ((self.voteCountYes.times(100)) / voterCount);
        var percentNo = ((self.voteCountNo.times(100)) / voterCount);        

        if (percentYes >= thresholdPercent) {
            self.state = ReferendumState.Accepted;
        } else if (percentNo >= thresholdPercent) {
            self.state = ReferendumState.Rejected;
        } else if (now > self.expiryTime) {
            self.state = ReferendumState.Expired;
        }

        return self.state;
    }
}