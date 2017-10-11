var SafeMathLib = artifacts.require("./SafeMathLib.sol");
var CitizenLib = artifacts.require("./CitizenLib.sol");
var ReferendumLib = artifacts.require("./ReferendumLib.sol");
var ParameterLib = artifacts.require("./ParameterLib.sol");
var ProposalLib = artifacts.require("./ProposalLib.sol");
var TaxLib = artifacts.require("./TaxLib.sol");
var TokenLib = artifacts.require("./TokenLib.sol");
var VillageCoin = artifacts.require("./VillageCoin.sol");
var SS = artifacts.require("./Storage.sol");


module.exports = function(deployer) 
{
  try
  { 
    var vc, ss;
    deployer.then(function() {
      // Create a new version of A
      return SS.new();// VillageCoin.new();
    }).then(function(instance) {
      ss = instance;
      SS.address = ss.address;
      return VillageCoin.new(ss.address);

    }).then(function(instance) {
      vc = instance;
      VillageCoin.address = vc.address

      ss.addWriter(vc.address);

      vc.addStringParameter("name", "RedditVillage", {gas: 6700000});
      vc.addStringParameter("symbol", "RVX", {gas: 6700000});
  
      vc.addNumberParameter( "decimals", 0, 0, 18, {gas: 6700000});
      vc.addNumberParameter("initialAccountBalance", 1000, 0, 0, {gas: 6700000});
      vc.addNumberParameter("proposalDecideThresholdPercent", 60, 0, 100, {gas: 6700000});
      vc.addNumberParameter("proposalTimeLimitDays", 30, 0, 0, {gas: 6700000});
      vc.addNumberParameter("citizenRequirementMinCommentKarma", 0, 0, 0, {gas: 6700000});
      vc.addNumberParameter("citizenRequirementMinPostKarma", 0, 0, 0, {gas: 6700000});
  
      vc.addNumberParameter("taxPeriodDays", 30, 1, 0, {gas: 6700000});
      vc.addNumberParameter("taxPollTax", 0, 0, 0, {gas: 6700000});
      vc.addNumberParameter("taxWealthTaxPercent", 0, 0, 100, {gas: 6700000});
      vc.addNumberParameter("taxBasicIncome", 0, 0, 0, {gas: 6700000});
      vc.addNumberParameter("taxTransactionTaxFlat", 0, 0, 0, {gas: 6700000});
      vc.addNumberParameter("taxTransactionTaxPercent", 0, 0, 100, {gas: 6700000});
      vc.addNumberParameter("taxProposalTaxFlat", 0, 0, 0, {gas: 6700000});
      return vc.addNumberParameter("taxProposalTaxPercent", 0, 0, 100, {gas: 6700000});                         
           
    }).then(function(){
      return vc.addCitizen("0x52ec249dd2eec428b1e2f389c7d032caf5d1a238", "felixwatts", {gas: 2000000});   
    });
  }
  catch(error)
  {
    console.log(error);
    throw(error);
  }
};