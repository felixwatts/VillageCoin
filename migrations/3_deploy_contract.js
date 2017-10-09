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
  try
  { 
    deployer.deploy(VillageCoin);
  }
  catch(error)
  {
    console.log(error);
    throw(error);
  }
};