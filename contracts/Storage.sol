pragma solidity ^0.4.9;

contract Storage {

    mapping(address=>bool) public _writers;

    mapping(bytes32=>uint) _uint;
    mapping(bytes32=>mapping(bytes32=>uint)) _uintByBytes32;
    mapping(address=>mapping(bytes32=>uint)) _uintByAddress;
    mapping(uint=>mapping(bytes32=>uint)) _uintByUInt;

    mapping(bytes32=>bool) _bool;
    mapping(bytes32=>mapping(bytes32=>bool)) _boolByBytes32;
    mapping(address=>mapping(bytes32=>bool)) _boolByAddress;
    mapping(uint=>mapping(bytes32=>bool)) _boolByUInt;

    mapping(bytes32=>address) _addr;
    mapping(bytes32=>mapping(bytes32=>address)) _addrByBytes32;
    mapping(address=>mapping(bytes32=>address)) _addrByAddr;
    mapping(uint=>mapping(bytes32=>address)) _addrByUInt;

    mapping(bytes32=>bytes32) _bytes32;
    mapping(bytes32=>mapping(bytes32=>bytes32)) _bytes32ByBytes32;
    mapping(address=>mapping(bytes32=>bytes32)) _bytes32ByAddress;
    mapping(uint=>mapping(bytes32=>bytes32)) _bytes32ByUInt;

    mapping(uint=>mapping(bytes32=>uint[64])) _arrByUInt;

    function Storage() payable {
        _writers[msg.sender] = true;
    }

    function addWriter(address writer) onlyWriter public {
        _writers[writer] = true;
    }

    function removeWriter(address writer) onlyWriter public {
        _writers[writer] = false;
    }

    function selfDestruct() onlyWriter public {
        selfdestruct(msg.sender);
    }

    //
    // Getters
    //

    function getUInt(bytes32 key) public constant returns(uint) {
        return _uint[key];
    }

    function getUInt(bytes32 key, address addr) public constant returns(uint) {
        return _uintByAddress[addr][key];
    }

    function getUInt(bytes32 key, uint n) public constant returns(uint) {
        return _uintByUInt[n][key];
    } 

    function getUInt(bytes32 key, bytes32 n) public constant returns(uint) {
        return _uintByBytes32[n][key];
    } 

    function getAddress(bytes32 key) public constant returns(address) {
        return _addr[key];
    }

    function getAddress(bytes32 key, uint n) public constant returns(address) {
        return _addrByUInt[n][key];
    }

    function getAddress(bytes32 key, address addr) public constant returns(address) {
        return _addrByAddr[addr][key];
    } 

    function getAddress(bytes32 key, bytes32 n) public constant returns(address) {
        return _addrByBytes32[n][key];
    } 

    function getBool(bytes32 key) public constant returns(bool) {
        return _bool[key];
    }

    function getBool(bytes32 key, uint n) public constant returns(bool) {
        return _boolByUInt[n][key];
    }

    function getBool(bytes32 key, address addr) public constant returns(bool) {
        return _boolByAddress[addr][key];
    } 

    function getBool(bytes32 key, bytes32 n) public constant returns(bool) {
        return _boolByBytes32[n][key];
    } 

    function getBytes32(bytes32 key) public constant returns(bytes32) {
        return _bytes32[key];
    }

    function getBytes32(bytes32 key, uint n) public constant returns(bytes32) {
        return _bytes32ByUInt[n][key];
    }

    function getBytes32(bytes32 key, address addr) public constant returns(bytes32) {
        return _bytes32ByAddress[addr][key];
    } 

    function getBytes32(bytes32 key, bytes32 n) public constant returns(bytes32) {
        return _bytes32ByBytes32[n][key];
    } 

    function getArr(bytes32 key, uint n) public constant returns(uint[64]) {
        return _arrByUInt[n][key];
    } 

    //
    // Setters
    //

    function setUInt(bytes32 key, uint val) public onlyWriter {
        _uint[key] = val;
    }

    function setUInt(bytes32 key, address addr, uint val) public onlyWriter {
        _uintByAddress[addr][key] = val;
    }

    function setUInt(bytes32 key, uint n, uint val) public onlyWriter {
        _uintByUInt[n][key] = val;
    }

    function setUInt(bytes32 key, bytes32 n, uint val) public onlyWriter {
        _uintByBytes32[n][key] = val;
    }

    function setBytes32(bytes32 key, bytes32 val) public onlyWriter {
        _bytes32[key] = val;
    }

    function setBytes32(bytes32 key, address addr, bytes32 val) public onlyWriter {
        _bytes32ByAddress[addr][key] = val;
    }

    function setBytes32(bytes32 key, uint n, bytes32 val) public onlyWriter {
        _bytes32ByUInt[n][key] = val;
    }

    function setBytes32(bytes32 key, bytes32 n, bytes32 val) public onlyWriter {
        _bytes32ByBytes32[n][key] = val;
    }

    function setBool(bytes32 key, bool val) public onlyWriter {
        _bool[key] = val;
    }

    function setBool(bytes32 key, address addr, bool val) public onlyWriter {
        _boolByAddress[addr][key] = val;
    }

    function setBool(bytes32 key, uint n, bool val) public onlyWriter {
        _boolByUInt[n][key] = val;
    }

    function setBool(bytes32 key, bytes32 n, bool val) public onlyWriter {
        _boolByBytes32[n][key] = val;
    }

    function setAddress(bytes32 key, address val) public onlyWriter {
        _addr[key] = val;
    }

    function setAddress(bytes32 key, address addr, address val) public onlyWriter {
        _addrByAddr[addr][key] = val;
    }

    function setAddress(bytes32 key, uint n, address val) public onlyWriter {
        _addrByUInt[n][key] = val;
    }

    function setAddress(bytes32 key, bytes32 n, address val) public onlyWriter {
        _addrByBytes32[n][key] = val;
    }

    function setArr(bytes32 key, uint n, uint[64] val) public constant returns(uint[64]) {
        return _arrByUInt[n][key] = val;
    } 

    //
    // Function Modifiers
    //   

    modifier onlyWriter {
        require(_writers[msg.sender]);
        _;
    }
}