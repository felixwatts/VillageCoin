import "./Storage.sol";


pragma solidity ^0.4.9;

// Parameters is a key-value store where the key is a string and the value can be either a string or a number
// Parameters are defined using the addString and addNumber functions
// Parameters can be get and set using getString, setString, getNumber, setNumber and set functions
// Undefined parameters cannot be get or set
// Number type parameters have an enforced min-max range. 
library ParameterLib {

    bytes32 constant public F_NUMBER_VALUE = sha3("F_PRM_NUMBER_VALUE");
    bytes32 constant public F_STRING_VALUE = sha3("F_PRM_STRING_VALUE");
    bytes32 constant public F_IS_NUMBER = sha3("F_PRM_IS_NUMBER");
    bytes32 constant public F_IS_EXISTENT = sha3("F_PRM_IS_EXISTENT");
    bytes32 constant public F_MIN_NUMBER_VALUE = sha3("F_PRM_MIN_NUMBER_VALUE");
    bytes32 constant public F_MAX_NUMBER_VALUE = sha3("F_PRM_MAX_NUMBER_VALUE");

    //
    // Views
    //

    function isParameter(Storage self, bytes32 name) public constant returns(bool) {
        return self.getBool(name, F_IS_EXISTENT);
    }

    function isNumberParameter(Storage self, bytes32 name) public constant returns(bool) {
        return isParameter(self, name) && self.getBool(name, F_IS_NUMBER);
    }

    function isStringParameter(Storage self, bytes32 name) public constant returns(bool) {
        return isParameter(self, name) && !self.getBool(name, F_IS_NUMBER);
    }

    function getString(Storage self, bytes32 name) public constant returns(bytes32) {
        require(isStringParameter(self, name));
        return self.getBytes32(name, F_STRING_VALUE);
    }

    function getNumber(Storage self, bytes32 name) public constant returns(uint) {
        require(isNumberParameter(self, name));
        return self.getUInt(name, F_NUMBER_VALUE);
    }

    function getNumberParameterRange(Storage self, bytes32 name) public constant returns(uint min, uint max) {
        require(isNumberParameter(self, name));
        min = self.getUInt(name, F_MIN_NUMBER_VALUE);
        max = self.getUInt(name, F_MAX_NUMBER_VALUE);
    }

    function validateValue(Storage self, bytes32 name, bytes32 stringValue, uint numberValue) public constant {
        if (isStringParameter(self, name)) {
            return;
        } else if (isNumberParameter(self, name)) {
            validateNumberValue(self, name, numberValue);
        } else {
            assert(false);
        }
    }

    function validateNumberValue(Storage self, bytes32 name, uint value) public constant {
        require(isNumberParameter(self, name));
        require(value >= self.getUInt(name, F_MIN_NUMBER_VALUE));
        uint max = self.getUInt(name, F_MAX_NUMBER_VALUE);
        require(max == 0 || value <= max);
    }

    //
    // Modifiers
    //

    function addString(Storage self, bytes32 name, bytes32 value) public {
        require(!isParameter(self, name));        
        self.setBool(name, F_IS_EXISTENT, true);
        self.setBool(name, F_IS_NUMBER, false);
        self.setBytes32(name, F_STRING_VALUE, value);
    }

    function addNumber(Storage self, bytes32 name, uint value, uint min, uint max) public {
        require(!isParameter(self, name));
        self.setBool(name, F_IS_EXISTENT, true);
        self.setBool(name, F_IS_NUMBER, true);
        self.setUInt(name, F_NUMBER_VALUE, value);
        self.setUInt(name, F_MIN_NUMBER_VALUE, min);
        self.setUInt(name, F_MAX_NUMBER_VALUE, max);
    }

    function set(Storage self, bytes32 name, bytes32 stringValue, uint numberValue) public {
        if (isStringParameter(self, name)) {
            setString(self, name, stringValue);
        } else if (isNumberParameter(self, name)) {
            setNumber(self, name, numberValue);
        } else {
            assert(false);
        }
    }

    function setString(Storage self, bytes32 name, bytes32 value) public {
        require(isStringParameter(self, name));
        self.setBytes32(name, F_STRING_VALUE, value);
    }

    function setNumber(Storage self, bytes32 name, uint value) public {
        validateNumberValue(self, name, value);
        self.setUInt(name, F_NUMBER_VALUE, value);
    }
}