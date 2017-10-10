pragma solidity ^0.4.9;

import "./SafeMathLib.sol";
import "./Storage.sol";

// Citizens is an iterable collection of Citizen objects
// Lookup is provided by either address or username
// Citizens can be added and removed
// No two Citizens may share an address or a username
// A count is maintained
// There is a special citizen with username '!PublicAccount' and address 0x0 that is always present and is not included in the iteration
library CitizenLib {

    using SafeMathLib for uint;

    bytes32 constant public F_USERNAME = sha3("F_CITIZEN_USERNAME");
    bytes32 constant public F_ADDRESS = sha3("F_CITIZEN_ADDRESS");
    bytes32 constant public F_IS_EXISTENT = sha3("F_CITIZEN_IS_EXISTENT");

    bytes32 constant public F_NEXT_ID = sha3("F_CITIZEN_NEXT_ID");
    bytes32 constant public F_COUNT = sha3("F_CITIZEN_COUNT");  
    bytes32 constant public F_ITERATION_INDEX = sha3("F_CITIZEN_ITERATION_INDEX");  

    bytes32 constant public F_ID_BY_ADDRESS = sha3("F_CITIZEN_ID_BY_ADDRESS");   
    bytes32 constant public F_ID_BY_USERNAME = sha3("F_CITIZEN_ID_BY_USERNAME");   

    // struct Citizens {
    //     mapping(uint=>Citizen) citizens;
    //     mapping(address=>uint) idByAddress;
    //     mapping(string=>uint) idByUsername;
    //     uint count;        
    //     uint iterationIndex;
    // }

    function iterateStart(Storage self) public {
        self.setUInt(F_ITERATION_INDEX, 0); // iteration skips public account
    }

    function iterateValid(Storage self) public returns(bool) {
        return self.getUInt(F_ITERATION_INDEX) < self.getUInt(F_COUNT);
    }

    function iterateNext(Storage self) public {
        do {
            self.setUInt(F_ITERATION_INDEX, self.getUInt(F_ITERATION_INDEX).plus(1));
        } while(iterateValid(self) && iterateCurrent(self) != 0x0);
    }

    function iterateCurrent(Storage self) public returns(address) {
        return self.getAddress(F_ADDRESS, self.getUInt(F_ITERATION_INDEX));
    }

    function add(Storage self, address addr, bytes32 username) public {
        require(sha3(username) != sha3(""));
        require(!isCitizen(self, addr));
        require(!isCitizen(self, username));

        uint id = self.getUInt(F_NEXT_ID);
        self.setUInt(F_NEXT_ID, self.getUInt(F_NEXT_ID).plus(1));
        assert(!self.getBool(F_IS_EXISTENT, id));

        self.setBool(F_IS_EXISTENT, id, true);
        self.setBytes32(F_USERNAME, id, username);
        self.setAddress(F_ADDRESS, id, addr);

        self.setUInt(F_ID_BY_ADDRESS, addr, id);
        self.setUInt(F_ID_BY_USERNAME, username, id);
        
        self.setUInt(F_COUNT, self.getUInt(F_COUNT).plus(1));
    }

    function remove(Storage self, bytes32 username) public {
        require(isCitizen(self, username));
        require(username != sha3("!PublicAccount")); // TODO
        uint id = self.getUInt(F_ID_BY_USERNAME, username);
        self.setBool(F_IS_EXISTENT, id, false);
        self.setUInt(F_COUNT, self.getUInt(F_COUNT).minus(1));
    }

    function isCitizen(Storage self, address addr) public constant returns(bool) {
        uint id = self.getUInt(F_ID_BY_ADDRESS, addr);
        return id != 0 && self.getBool(F_IS_EXISTENT, id);
    }

    function isCitizen(Storage self, bytes32 username) public constant returns(bool) {
        uint id = self.getUInt(F_ID_BY_USERNAME, username);
        return id != 0 && self.getBool(F_IS_EXISTENT, id);
    }

    function getAddress(Storage self, bytes32 username) public constant returns(address) {
        require(isCitizen(self, username));
        return self.getAddress(F_ADDRESS, self.getUInt(F_ID_BY_USERNAME, username));
    }

    function getUsername(Storage self, address addr) public returns(bytes32) {
        require(isCitizen(self, addr));
        return self.getBytes32(F_USERNAME, self.getUInt(F_ID_BY_ADDRESS, addr));
    } 
}