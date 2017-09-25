pragma solidity ^0.4.9;

import "./SafeMathLib.sol";

library CitizenLib {

    using SafeMathLib for uint;

    struct Citizenry {
        //
        // TODO be careful if you ever add removal of citizens, count is sometimes used as
        // an actual count of citizens and sometimes as the length of allCitizensEver
        //
        mapping(address=>string) usernameByAddress;
        mapping(string=>address) addressByUsername;
        uint count;
        address[] allCitizensEver;
    }

    function add(Citizenry storage self, address addr, string username) public {
        require(addr != 0x0);
        require(sha3(username) != sha3(""));
        require(!self.isCitizen(addr));
        require(!self.isCitizen(username));

        self.usernameByAddress[addr] = username;
        self.addressByUsername[username] = addr;
        self.count = self.count.plus(1);
        self.allCitizensEver.push(addr);
    }

    function isCitizen(Citizenry storage self, address addr) public constant returns(bool) {
        return sha3(self.usernameByAddress[addr]) != sha3("");
    }

    function isCitizen(Citizenry storage self, string username) public constant returns(bool) {
        return self.addressByUsername[username] != 0x0;
    }

    function getAddress(Citizenry storage self, string username) public constant returns(address) {
        require(self.isCitizen(username));
        return self.addressByUsername[username];
    }
}