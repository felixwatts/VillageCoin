pragma solidity ^0.4.9;

import "./SafeMathLib.sol";

// Citizens is an iterable collection of Citizen objects
// Lookup is provided by either address or username
// Citizens can be added and removed
// No two Citizens may share an address or a username
// A count is maintained
// There is a special citizen with username '!PublicAccount' and address 0x0 that is always present and is not included in the iteration
library CitizenLib {

    using SafeMathLib for uint;

    struct Citizen {
        string username;
        address addr;
        bool isExistent;
    }

    struct Citizens {
        uint nextId;
        mapping(uint=>Citizen) citizens;
        mapping(address=>uint) idByAddress;
        mapping(string=>uint) idByUsername;
        uint count;        
        uint iterationIndex;
    }

    function init(Citizens storage self) public {
        assert(self.nextId == 0);

        add(self, 0x0, "!PublicAccount");
        self.count = 0; // public account doesnt count towards population because it doesnt vote
    }

    function iterateStart(Citizens storage self) public {
        self.iterationIndex = 0; // iteration skips public account
    }

    function iterateValid(Citizens storage self) public returns(bool) {
        return self.iterationIndex < self.nextId;
    }

    function iterateNext(Citizens storage self) public {
        do {
            self.iterationIndex = self.iterationIndex.plus(1);
        } while(iterateValid(self) && iterateCurrent(self) != 0x0);
    }

    function iterateCurrent(Citizens storage self) public returns(address) {
        return self.citizens[self.iterationIndex].addr;
    }

    function add(Citizens storage self, address addr, string username) public {
        require(sha3(username) != sha3(""));
        require(!isCitizen(self, addr));
        require(!isCitizen(self, username));

        uint id = self.nextId;
        self.nextId = self.nextId.plus(1);
        assert(!self.citizens[id].isExistent);

        self.citizens[id].isExistent = true;
        self.citizens[id].username = username;
        self.citizens[id].addr = addr;

        self.idByAddress[addr] = id;
        self.idByUsername[username] = id;
        
        self.count = self.count.plus(1);
    }

    function remove(Citizens storage self, string username) public {
        require(isCitizen(self, username));
        require(sha3(username) != sha3("!PublicAccount"));
        uint id = self.idByUsername[username];
        self.citizens[id].isExistent = false;
        self.count = self.count.minus(1);
    }

    function isCitizen(Citizens storage self, address addr) public constant returns(bool) {
        uint id = self.idByAddress[addr];
        return id != 0 && self.citizens[id].isExistent;        
    }

    function isCitizen(Citizens storage self, string username) public constant returns(bool) {
        uint id = self.idByUsername[username];
        return id != 0 && self.citizens[id].isExistent;
    }

    function getAddress(Citizens storage self, string username) public constant returns(address) {
        require(isCitizen(self, username));
        return self.citizens[self.idByUsername[username]].addr;
    }

    function getUsername(Citizens storage self, address addr) public returns(string) {
        require(isCitizen(self, addr));
        return self.citizens[self.idByAddress[addr]].username;
    } 
}