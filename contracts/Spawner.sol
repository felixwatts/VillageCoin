pragma solidity ^0.4.9;

import "./VillageCoin.sol";

contract Spawner {  

    event OnVillageCreated(address addr);

    mapping(uint=>address) _villages;
    uint _villageCount; 

    function Spawner() payable {
    }  

    function getVillageAddress(uint id) public constant returns (address) {
        return _villages[id];
    }

    function getVillageCount() public constant returns (uint) {
        return _villageCount;
    }

    // function spawnVillage(string name, string symbol, uint8 decimals, string accessPolicyDescription, string accessEvidenceRequirementsDescription) public {
    //     var village = new VillageCoin(name, symbol, decimals, msg.sender, accessPolicyDescription, accessEvidenceRequirementsDescription);
    //     _villages[_villageCount++] = village;        
    //     OnVillageCreated(village);
    // }
}