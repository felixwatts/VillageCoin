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
        return self.getBool(F_IS_EXISTENT, name);
    }

    function isNumberParameter(Storage self, bytes32 name) public constant returns(bool) {
        return isParameter(self, name) && self.getBool(F_IS_NUMBER, name);
    }

    function isStringParameter(Storage self, bytes32 name) public constant returns(bool) {
        return isParameter(self, name) && !self.getBool(F_IS_NUMBER, name);
    }

    function getString(Storage self, bytes32 name) public constant returns(bytes32) {
        require(isStringParameter(self, name));
        return self.getBytes32(F_STRING_VALUE, name);
    }

    function getNumber(Storage self, bytes32 name) public constant returns(uint) {
        require(isNumberParameter(self, name));
        return self.getUInt(F_NUMBER_VALUE, name);
    }

    function getNumberParameterRange(Storage self, bytes32 name) public constant returns(uint min, uint max) {
        require(isNumberParameter(self, name));
        min = self.getUInt(F_MIN_NUMBER_VALUE, name);
        max = self.getUInt(F_MAX_NUMBER_VALUE, name);
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
        require(value >= self.getUInt(F_MIN_NUMBER_VALUE, name));
        uint max = self.getUInt(F_MAX_NUMBER_VALUE, name);
        require(max == 0 || value <= max);
    }

    //
    // Modifiers
    //

    function addString(Storage self, bytes32 name, bytes32 value) public {
        require(!isParameter(self, name));        
        self.setBool(F_IS_EXISTENT, name, true);
        self.setBool(F_IS_NUMBER, name, false);
        self.setBytes32(F_STRING_VALUE, name, value);
    }

    function addNumber(Storage self, bytes32 name, uint value, uint min, uint max) public {
        require(!isParameter(self, name));
        self.setBool(F_IS_EXISTENT, name, true);
        self.setBool(F_IS_NUMBER, name, true);
        self.setUInt(F_NUMBER_VALUE, name, value);
        self.setUInt(F_MIN_NUMBER_VALUE, name, min);
        self.setUInt(F_MAX_NUMBER_VALUE, name, max);
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
        self.setBytes32(F_STRING_VALUE, name, value);
    }

    function setNumber(Storage self, bytes32 name, uint value) public {
        validateNumberValue(self, name, value);
        self.setUInt(F_NUMBER_VALUE, name, value);
    }
}