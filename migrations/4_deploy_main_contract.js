var Storage = artifacts.require("./Storage.sol");
var VillageCoin = artifacts.require("./VillageCoin.sol");

module.exports = function(deployer) 
{

  deployer
    .then(function(){
    return Storage.deployed();
  }).then(function(storage){
    return deployer.deploy(VillageCoin, storage.address);
  });
};