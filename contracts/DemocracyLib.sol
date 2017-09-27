pragma solidity ^0.4.9;

import "./SafeMathLib.sol";

library DemocracyLib {

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