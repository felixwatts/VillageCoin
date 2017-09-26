var SafeMathLib = artifacts.require("SafeMathLib");
var CitizenLib = artifacts.require("CitizenLib");
var DemocracyLib = artifacts.require("DemocracyLib");
var ParameterLib = artifacts.require("ParameterLib");
var ProposalLib = artifacts.require("ProposalLib");
var TaxLib = artifacts.require("TaxLib");
var TokenLib = artifacts.require("TokenLib");
var VillageCoin = artifacts.require("VillageCoin");


module.exports = async function(deployer) {
  await deployer.deploy(SafeMathLib);

  deployer.link(SafeMathLib, TokenLib);
  await deployer.deploy(TokenLib);
  deployer.link(TokenLib, TaxLib);

  deployer.link(SafeMathLib, VillageCoin);
  deployer.link(SafeMathLib, CitizenLib);
  deployer.link(SafeMathLib, DemocracyLib);
  deployer.link(SafeMathLib, ProposalLib);
  deployer.link(SafeMathLib, TaxLib);

  await deployer.deploy(CitizenLib);
  await deployer.deploy(DemocracyLib);
  await deployer.deploy(ParameterLib);
  await deployer.deploy(ProposalLib);
  await deployer.deploy(TaxLib);
  
  deployer.link(CitizenLib, VillageCoin);
  deployer.link(DemocracyLib, VillageCoin);
  deployer.link(ParameterLib, VillageCoin);
  deployer.link(ProposalLib, VillageCoin);
  deployer.link(TaxLib, VillageCoin);
  deployer.link(TokenLib, VillageCoin);

  await deployer.deploy(VillageCoin);
};
