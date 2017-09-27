pragma solidity ^0.4.9;

import "./SafeMathLib.sol";

library CitizenLib {

    using SafeMathLib for uint;

    struct Citizen {
        string username;
        address addr;
        bool isExistent;
    }

    struct Citizenry {
        string[] allUsernamesEver;
        mapping(address=>string) usernameByAddress;
        mapping(string=>Citizen) citizenByUsername;
        uint count;        
        int iterationIndex;
    }

    function init(Citizenry storage self) public {
        assert(self.allUsernamesEver.length == 0);

        self.citizenByUsername["!PublicAccount"].isExistent = true;
        self.citizenByUsername["!PublicAccount"].username = "!PublicAccount";
        self.citizenByUsername["!PublicAccount"].addr = 0x0;
        self.usernameByAddress[0x0] = "!PublicAccount";
    }

    function iterateStart(Citizenry storage self) public {
        self.iterationIndex = -1;
    }

    function iterateValid(Citizenry storage self) public returns(bool) {
        return uint(self.iterationIndex) < self.allUsernamesEver.length;
    }

    function iterateNext(Citizenry storage self) public {
        do {
            self.iterationIndex += 1;
        } while(iterateValid(self) && iterateCurrent(self) != 0x0);
    }

    function iterateCurrent(Citizenry storage self) public returns(address) {
        return self.citizenByUsername[self.allUsernamesEver[uint(self.iterationIndex)]].addr;
    }

    function add(Citizenry storage self, address addr, string username) public {
        require(addr != 0x0);
        require(sha3(username) != sha3(""));
        require(!isCitizen(self, addr));
        require(!isCitizen(self, username));

        self.citizenByUsername[username].isExistent = true;
        self.citizenByUsername[username].username = username;
        self.citizenByUsername[username].addr = addr;

        self.usernameByAddress[addr] = username;
        
        self.count = self.count.plus(1);

        self.allUsernamesEver.push(username);
    }

    function remove(Citizenry storage self, string username) public {
        require(isCitizen(self, username));
        self.citizenByUsername[username].isExistent = false;
        self.count = self.count.minus(1);
    }

    function isCitizen(Citizenry storage self, address addr) public constant returns(bool) {
        return self.citizenByUsername[self.usernameByAddress[addr]].isExistent;
    }

    function isCitizen(Citizenry storage self, string username) public constant returns(bool) {
        return self.citizenByUsername[username].isExistent;
    }

    function getAddress(Citizenry storage self, string username) public constant returns(address) {
        require(isCitizen(self, username));
        return self.citizenByUsername[username].addr;
    }
}