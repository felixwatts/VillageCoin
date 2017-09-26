var SafeMathLib = artifacts.require("SafeMathLib");
var CitizenLib = artifacts.require("CitizenLib");
var DemocracyLib = artifacts.require("DemocracyLib");
var ParameterLib = artifacts.require("ParameterLib");
var ProposalLib = artifacts.require("ProposalLib");
var TaxLib = artifacts.require("TaxLib");
var TokenLib = artifacts.require("TokenLib");
var VillageCoin = artifacts.require("VillageCoin");


module.exports = function(deployer) {
  deployer.deploy(SafeMathLib);

  deployer.link(SafeMathLib, TokenLib);
  deployer.deploy(TokenLib);
  deployer.link(TokenLib, TaxLib);

  deployer.link(SafeMathLib, VillageCoin);
  deployer.link(SafeMathLib, CitizenLib);
  deployer.link(SafeMathLib, DemocracyLib);
  deployer.link(SafeMathLib, ProposalLib);
  deployer.link(SafeMathLib, TaxLib);

  deployer.deploy(CitizenLib);
  deployer.deploy(DemocracyLib);
  deployer.deploy(ParameterLib);
  deployer.deploy(ProposalLib);
  deployer.deploy(TaxLib);
  
  deployer.link(CitizenLib, VillageCoin);
  deployer.link(DemocracyLib, VillageCoin);
  deployer.link(ParameterLib, VillageCoin);
  deployer.link(ProposalLib, VillageCoin);
  deployer.link(TaxLib, VillageCoin);
  deployer.link(TokenLib, VillageCoin);

  deployer.deploy(VillageCoin);
};
