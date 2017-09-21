var SafeMath = artifacts.require("SafeMath");
var ContractReceiver = artifacts.require("ContractReceiver");
var ERC223 = artifacts.require("ERC223");
var Spawner = artifacts.require("Spawner");
var VillageCoin = artifacts.require("VillageCoin");


module.exports = function(deployer) {
  deployer.deploy(SafeMath);
  deployer.deploy(ContractReceiver);
  deployer.link(SafeMath, VillageCoin);
  deployer.link(ContractReceiver, VillageCoin);
  deployer.deploy(Spawner);
  //deployer.link(Spawner, VillageCoin);
  deployer.deploy(VillageCoin, "RedditCoin", "RCX", 0);
};
