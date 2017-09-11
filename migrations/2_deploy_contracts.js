var SafeMath = artifacts.require("SafeMath");
var ContractReceiver = artifacts.require("ContractReceiver");
var ERC223 = artifacts.require("ERC223");
var VillageCoin = artifacts.require("VillageCoin");


module.exports = function(deployer) {
  deployer.deploy(SafeMath);
  //deployer.deploy(ERC223, {gas: 1000000});
  deployer.deploy(ContractReceiver);
  deployer.link(SafeMath, VillageCoin);
  //deployer.link(ERC223, VillageCoin);
  deployer.link(ContractReceiver, VillageCoin);
  deployer.deploy(VillageCoin, "VillageCOin", "VGC", 0);
};
