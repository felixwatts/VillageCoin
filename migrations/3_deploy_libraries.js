var SafeMathLib = artifacts.require("./SafeMathLib.sol");
var CitizenLib = artifacts.require("./CitizenLib.sol");
var ReferendumLib = artifacts.require("./ReferendumLib.sol");
var ParameterLib = artifacts.require("./ParameterLib.sol");
var ProposalLib = artifacts.require("./ProposalLib.sol");
var TaxLib = artifacts.require("./TaxLib.sol");
var TokenLib = artifacts.require("./TokenLib.sol");
var VillageCoin = artifacts.require("./VillageCoin.sol");

module.exports = function(deployer) 
{
  deployer.deploy(SafeMathLib);
  
  deployer.link(SafeMathLib, TokenLib);
  deployer.deploy(TokenLib);
  deployer.link(TokenLib, TaxLib);

  deployer.link(SafeMathLib, VillageCoin);
  deployer.link(SafeMathLib, CitizenLib);
  deployer.link(SafeMathLib, ReferendumLib);
  deployer.link(SafeMathLib, ProposalLib);
  deployer.link(SafeMathLib, TaxLib);

  deployer.deploy(ParameterLib);
  deployer.link(ParameterLib, ProposalLib);
  deployer.link(TokenLib, ProposalLib);    

  deployer.deploy(CitizenLib);
  deployer.deploy(ReferendumLib);
  
  deployer.deploy(ProposalLib);
  deployer.deploy(TaxLib);
  
  deployer.link(CitizenLib, VillageCoin);
  deployer.link(ReferendumLib, VillageCoin);
  deployer.link(ParameterLib, VillageCoin);
  deployer.link(ProposalLib, VillageCoin);
  deployer.link(TaxLib, VillageCoin);
  deployer.link(TokenLib, VillageCoin);
};