pragma solidity ^0.4.9;

// Parameters is a key-value store where the key is a string and the value can be either a string or a number
// Parameters are defined using the addString and addNumber functions
// Parameters can be get and set using getString, setString, getNumber, setNumber and set functions
// Undefined parameters cannot be get or set
// Number type parameters have an enforced min-max range. 
library ParameterLib {

    struct Parameter {
        uint numberValue;
        string stringValue;
        bool isNumber;
        bool isExistent;
        uint minNumberValue;
        uint maxNumberValue; // 0 = no max
    }

    struct Parameters {
        mapping(string=>Parameter) parameters;
    }

    //
    // Views
    //

    function isParameter(Parameters storage self, string name) public constant returns(bool) {
        return self.parameters[name].isExistent;
    }

    function isNumberParameter(Parameters storage self, string name) public constant returns(bool) {
        return self.parameters[name].isExistent && self.parameters[name].isNumber;
    }

    function isStringParameter(Parameters storage self, string name) public constant returns(bool) {
        return self.parameters[name].isExistent && !self.parameters[name].isNumber;
    }

    function getString(Parameters storage self, string name) public returns(string) {
        require(self.parameters[name].isExistent);
        require(!self.parameters[name].isNumber);

        return self.parameters[name].stringValue;
    }

    function getNumber(Parameters storage self, string name) public returns(uint) {
        require(self.parameters[name].isExistent);
        require(self.parameters[name].isNumber);

        return self.parameters[name].numberValue;
    }

    function validateValue(Parameters storage self, string name, string stringValue, uint numberValue) public constant {
        if (isStringParameter(self, name)) {
            return;
        } else if (isNumberParameter(self, name)) {
            validateNumberValue(self, name, numberValue);
        } else {
            assert(false);
        }
    }

    function validateNumberValue(Parameters storage self, string name, uint value) public constant {
        require(self.parameters[name].isExistent);
        require(self.parameters[name].isNumber);
        require(value >= self.parameters[name].minNumberValue);
        require(self.parameters[name].maxNumberValue == 0 || value <= self.parameters[name].maxNumberValue);
    }

    //
    // Modifiers
    //

    function addString(Parameters storage self, string name, string value) public {
        require(!self.parameters[name].isExistent);
        self.parameters[name] = Parameter({stringValue:value, numberValue:0, isNumber:false, isExistent:true, minNumberValue:0, maxNumberValue:0});
    }

    function addNumber(Parameters storage self, string name, uint value, uint minValue, uint maxValue) public {
        require(!self.parameters[name].isExistent);
        self.parameters[name] = Parameter({stringValue:"", numberValue:value, isNumber:true, isExistent:true, minNumberValue:minValue, maxNumberValue:maxValue});
    }

    function set(Parameters storage self, string name, string stringValue, uint numberValue) public {
        if (isStringParameter(self, name)) {
            setString(self, name, stringValue);
        } else if (isNumberParameter(self, name)) {
            setNumber(self, name, numberValue);
        } else {
            assert(false);
        }
    }

    function setString(Parameters storage self, string name, string value) public {
        require(self.parameters[name].isExistent);
        require(!self.parameters[name].isNumber);

        self.parameters[name].stringValue = value;
    }

    function setNumber(Parameters storage self, string name, uint value) public {
        validateNumberValue(self, name, value);

        self.parameters[name].numberValue = value;
    }
}