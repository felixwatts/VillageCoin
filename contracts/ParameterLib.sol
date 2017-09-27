pragma solidity ^0.4.9;

library ParameterLib {

    struct Parameter {
        uint numberValue;
        string stringValue;
        bool isNumber;
        bool isExistent;
        uint minNumberValue;
        uint maxNumberValue; // 0 = no max
    }

    struct ParameterSet {
        mapping(string=>Parameter) parameters;
    }

    //
    // Views
    //

    function isParameter(ParameterSet storage self, string name) public constant returns(bool) {
        return self.parameters[name].isExistent;
    }

    function isNumberParameter(ParameterSet storage self, string name) public constant returns(bool) {
        return self.parameters[name].isExistent && self.parameters[name].isNumber;
    }

    function isStringParameter(ParameterSet storage self, string name) public constant returns(bool) {
        return self.parameters[name].isExistent && !self.parameters[name].isNumber;
    }

    function getString(ParameterSet storage self, string name) public returns(string) {
        require(self.parameters[name].isExistent);
        require(!self.parameters[name].isNumber);

        return self.parameters[name].stringValue;
    }

    function getNumber(ParameterSet storage self, string name) public returns(uint) {
        require(self.parameters[name].isExistent);
        require(self.parameters[name].isNumber);

        return self.parameters[name].numberValue;
    }

    //
    // Modifiers
    //

    function addString(ParameterSet storage self, string name, string value) public {
        require(!self.parameters[name].isExistent);
        self.parameters[name] = Parameter({stringValue:value, numberValue:0, isNumber:false, isExistent:true, minNumberValue:0, maxNumberValue:0});
    }

    function addNumber(ParameterSet storage self, string name, uint value, uint minValue, uint maxValue) public {
        require(!self.parameters[name].isExistent);
        self.parameters[name] = Parameter({stringValue:"", numberValue:value, isNumber:true, isExistent:true, minNumberValue:minValue, maxNumberValue:maxValue});
    }

    function set(ParameterSet storage self, string name, string stringValue, uint numberValue) public {
        if (isStringParameter(self, name)) {
            setString(self, name, stringValue);
        } else if (isNumberParameter(self, name)) {
            setNumber(self, name, numberValue);
        } else {
            revert();
        }
    }

    function setString(ParameterSet storage self, string name, string value) public {
        require(self.parameters[name].isExistent);
        require(!self.parameters[name].isNumber);

        self.parameters[name].stringValue = value;
    }

    function setNumber(ParameterSet storage self, string name, uint value) public {
        require(self.parameters[name].isExistent);
        require(self.parameters[name].isNumber);
        require(value >= self.parameters[name].minNumberValue);
        require(self.parameters[name].maxNumberValue == 0 || value <= self.parameters[name].maxNumberValue);

        self.parameters[name].numberValue = value;
    }
}