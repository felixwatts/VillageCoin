pragma solidity ^0.4.9;

import "./SafeMathLib.sol";
import "./Storage.sol";

// This models a collection of Accounts stored in a Storage
// An Account models a single named or anonymous user of the system
// An Account has an Id, an Address and optionally a Username
// All three fields of an account are unique, (the username must be 0 or unique)
// The collection is iterable
// Currently accounts cannot be removed/deleted
// If an account has a non-zero Username then it is called a Citizen.
//  Citizens can vote
//  Citizens are entitled to basic income
// A count of Citizens is maintained
library AccountLib {

    using SafeMathLib for uint;

    bytes32 constant public F_USERNAME = sha3("F_ACCOUNT_USERNAME");
    bytes32 constant public F_ADDRESS = sha3("F_ACCOUNT_ADDRESS");
    bytes32 constant public F_IS_EXISTENT = sha3("F_ACCOUNT_IS_EXISTENT");

    bytes32 constant public F_NEXT_ID = sha3("F_ACCOUNT_NEXT_ID");
    bytes32 constant public F_CITIZEN_COUNT = sha3("F_ACCOUNT_CITIZEN_COUNT");  
    bytes32 constant public F_ITERATION_INDEX = sha3("F_ACCOUNT_ITERATION_INDEX");  

    bytes32 constant public F_ID_BY_ADDRESS = sha3("F_ACCOUNT_ID_BY_ADDRESS");   
    bytes32 constant public F_ID_BY_USERNAME = sha3("F_ACCOUNT_ID_BY_USERNAME");   

    // Iteration functions allow iteration over the addresses of non-deleted accounts

    function iterateStart(Storage self) public {
        self.setUInt(F_ITERATION_INDEX, 0);
    }

    function iterateValid(Storage self) public returns(bool) {
        return self.getUInt(F_ITERATION_INDEX) < self.getUInt(F_NEXT_ID);
    }

    function iterateNext(Storage self) public {
        do {
            self.setUInt(F_ITERATION_INDEX, self.getUInt(F_ITERATION_INDEX).plus(1));
        } while(iterateValid(self) && self.getBool(F_IS_EXISTENT, self.getUInt(F_ITERATION_INDEX)));
    }

    function iterateCurrent(Storage self) public returns(address) {
        return self.getAddress(F_ADDRESS, self.getUInt(F_ITERATION_INDEX));
    }

    // Both citizens and anonymous accounts should be registered before they are used
    // to send or receive tokens. This enables taxes to be applied to the account
    //
    // This function can be called whether or not the specified address is a registered account
    // After the function returns the account is registered
    //
    // Uniqueness of account address is enforced
    //
    // The Id of the account is returned
    function ensureAccountIsRegistered(Storage self, address addr) public returns(uint) {
        require(addr != 0x0);
        
        uint id = self.getUInt(F_ID_BY_ADDRESS, addr);
        if (id != 0) {
            return id;
        }

        id = self.getUInt(F_NEXT_ID);
        if (id == 0) {
            id = 1; // zero is not a valid ID
        }        
        self.setUInt(F_NEXT_ID, id.plus(1));
        assert(!self.getBool(F_IS_EXISTENT, id));

        self.setBool(F_IS_EXISTENT, id, true);
        self.setAddress(F_ADDRESS, id, addr);

        self.setUInt(F_ID_BY_ADDRESS, addr, id); 

        return id;          
    }

    // Registers a new Citizen account
    // This should only be called after checking that the user meets the requirements for citizenship
    // Fails if the username is already registered
    // Safe to call if the address is already an account - the username will simply be associated with the existing account
    // Conversely, if the address is not already an account then the account will first be registered
    // Enforces uniqueness of username and address
    // Increments the citizen count
    function registerCitizen(Storage self, address addr, bytes32 username) public {
        require(addr != 0x0);
        require(username != 0);
        require(!isCitizen(self, username));
        require(!isCitizen(self, addr));

        var id = ensureAccountIsRegistered(self, addr);

        self.setBytes32(F_USERNAME, id, username);
        self.setUInt(F_ID_BY_USERNAME, username, id);
        
        self.setUInt(F_CITIZEN_COUNT, self.getUInt(F_CITIZEN_COUNT).plus(1));
    }

    // Returns true if the address is a registered account
    function isAccount(Storage self, address addr) public constant returns(bool) {
        uint id = self.getUInt(F_ID_BY_ADDRESS, addr);
        return id != 0;
    }

    // Returns true if the address is associated with a Citizen account
    function isCitizen(Storage self, address addr) public constant returns(bool) {
        var id = self.getUInt(F_ID_BY_ADDRESS, addr);
        if (id == 0) {
            return false;
        }
        return self.getBytes32(F_USERNAME, id) != 0;
    }

    // Returns true if the username is assoicated with a Citizen account
    function isCitizen(Storage self, bytes32 username) public constant returns(bool) {
        uint id = self.getUInt(F_ID_BY_USERNAME, username);
        return id != 0;
    }

    // Gets the address associated with the username, or 0 if the username is not a citizen
    function getAddress(Storage self, bytes32 username) public constant returns(address) {
        require(isCitizen(self, username));
        return self.getAddress(F_ADDRESS, self.getUInt(F_ID_BY_USERNAME, username));
    }

    // Gets the username associated with an address, fails if the address is not a citizen
    function getUsername(Storage self, address addr) public returns(bytes32) {
        require(isCitizen(self, addr));
        return self.getBytes32(F_USERNAME, self.getUInt(F_ID_BY_ADDRESS, addr));
    } 

    // Returns the current number of registered citizens (voters)
    function getPopulation(Storage self) public constant returns(uint) {
        return self.getUInt(F_CITIZEN_COUNT);
    }

    // Gets all the details of the account with the given id
    function get(Storage self, uint id) public constant returns(bytes32 username, address addr, bool isExistent) {
        username = self.getBytes32(F_USERNAME, id);
        addr = self.getAddress(F_ADDRESS, id);
        isExistent = self.getBool(F_IS_EXISTENT, id);
        return;
    }

    // Gets all the details of the account with the given username
    function get(Storage self, bytes32 username) public constant returns(address addr, bool isExistent) {
        var id = self.getUInt(F_ID_BY_USERNAME, username);
        if (id != 0) {
            addr = self.getAddress(F_ADDRESS, id);
            isExistent = self.getBool(F_IS_EXISTENT, id);
        }
        return;
    }

    // Gets all the details of the account with the given address
    function get(Storage self, address addr) public constant returns(bytes32 username, bool isExistent) {
        var id = self.getUInt(F_ID_BY_ADDRESS, addr);
        if (id != 0) {
            username = self.getBytes32(F_USERNAME, id);
            isExistent = self.getBool(F_IS_EXISTENT, id);
        }
        return;
    }

    // Gets the next unused Id, all numbers lower than this have already been used as Ids
    function getNextId(Storage self) public constant returns (uint) {
        return self.getUInt(F_NEXT_ID);
    }
}