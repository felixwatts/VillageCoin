var VillageCoin = artifacts.require("./VillageCoin.sol");
var Storage = artifacts.require("./Storage.sol");


module.exports = function(deployer) 
{

  var vc, st;

  deployer.then(function(){
    return VillageCoin.deployed();
  }).then(function(v){
    vc = v;
    return Storage.deployed();
  }).then(function(s){
    st = s;
    s.addWriter(vc.address);
  }).then(function(){
 
    vc.addStringParameter(web3.sha3("PRM_NAME"), "RedditVillage");
    vc.addStringParameter(web3.sha3("PRM_SYMBOL"), "RVX");
  
    vc.addNumberParameter(web3.sha3("PRM_DECIMALS"), 0, 0, 18);
    vc.addNumberParameter(web3.sha3("PRM_INITIAL_ACCOUNT_BALANCE"), 1000, 0, 0);
    vc.addNumberParameter(web3.sha3("PRM_PROPOSAL_DECIDE_THRESHOLD_PERCENT"), 60, 0, 100);
    vc.addNumberParameter(web3.sha3("PRM_PROPOSAL_TIME_LIMIT_DAYS"), 30, 0, 0);
    vc.addNumberParameter(web3.sha3("PRM_CITIZEN_REQUIREMENT_MIN_COMMENT_KARMA"), 0, 0, 0);
    vc.addNumberParameter(web3.sha3("PRM_CITIZEN_REQUIREMENT_MIN_POST_KARMA"), 0, 0, 0);
  
    vc.addNumberParameter(web3.sha3("PRM_TAX_PERIOD_DAYS"), 30, 1, 0);
    vc.addNumberParameter(web3.sha3("PRM_POLL_TAX"), 0, 0, 0);
    vc.addNumberParameter(web3.sha3("PRM_WEALTH_TAX_PERCENT"), 0, 0, 100);
    vc.addNumberParameter(web3.sha3("PRM_BASIC_INCOME"), 0, 0, 0);
    vc.addNumberParameter(web3.sha3("PRM_TRANSACTION_TAX_FLAT"), 0, 0, 0);
    vc.addNumberParameter(web3.sha3("PRM_TRANSACTION_TAX_PERCENT"), 0, 0, 100);
    vc.addNumberParameter(web3.sha3("PRM_PROPOSAL_TAX_FLAT"), 0, 0, 0);
    vc.addNumberParameter(web3.sha3("PRM_PROPOSAL_TAX_PERCENT"), 0, 0, 100); 
  
    vc.addCitizen("0x52ec249dd2eec428b1e2f389c7d032caf5d1a238", "!gatekeeper!");
  });
};