// Import the page's CSS. Webpack will know what to do with it.
import "../stylesheets/app.css";

// Import libraries we need.
import { default as Web3} from 'web3';
import { default as contract } from 'truffle-contract'

// Import our contract artifacts and turn them into usable abstractions.
import villagecoin_artifacts from '../../build/contracts/VillageCoin.json'

var ProposalType = {};
ProposalType.CreateManager = 0; 
ProposalType.DeleteManager = 1; 
ProposalType.CreateAccount = 2; 
ProposalType.DeleteAccount = 3; 
ProposalType.SetContractParameters = 4; 
ProposalType.CreateMoney = 5;
ProposalType.TaxWealth = 6; 
ProposalType.SpendPublicMoney = 7;

// VillageCoin is our usable abstraction, which we'll use through the code below.
var VillageCoin = contract(villagecoin_artifacts);

// The following code is simple to show off interacting with your contracts.
// As your needs grow you will likely need to change its form and structure.
// For application bootstrapping, check out window.addEventListener below.
var accounts;
var account;

function filterProposalBasicDetailsByExistentAndType(proposal, requiredType) {
  var isExistent = proposal[1];
  var hasSenderVoted = proposal[2];
  var proposalType = proposal[3];   
  
  console.log(proposal);
  console.log(requiredType);

  return isExistent && !hasSenderVoted && proposalType == requiredType;
}

window.App = {
  start: function() {
    var self = this;

    // Bootstrap the MetaCoin abstraction for Use.
    VillageCoin.setProvider(web3.currentProvider);

    // Get the initial account balance so it can be displayed.
    web3.eth.getAccounts(function(err, accs) {
      if (err != null) {
        alert("There was an error fetching your accounts.");
        return;
      }

      if (accs.length == 0) {
        alert("Couldn't get any accounts! Make sure your Ethereum client is configured correctly.");
        return;
      }

      accounts = accs;
      account = accounts[0];
    });
  },

  setStatus: function(message) {
    var status = document.getElementById("status");
    status.innerHTML = message;
  },

  // refreshBalance: function() {
  //   var self = this;

  //   var meta;
  //   MetaCoin.deployed().then(function(instance) {
  //     meta = instance;
  //     return meta.getBalance.call(account, {from: account});
  //   }).then(function(value) {
  //     var balance_element = document.getElementById("balance");
  //     balance_element.innerHTML = value.valueOf();
  //   }).catch(function(e) {
  //     console.log(e);
  //     self.setStatus("Error getting balance; see log.");
  //   });
  // },

  proposeCreateManager: function() {
    var self = this;

    var managerAddress = document.getElementById("managerAddress").value;

    this.setStatus("Initiating transaction... (please wait)");

    var villageCoin;
    VillageCoin.deployed().then(function(instance) {
      villageCoin = instance;
      return villageCoin.proposeCreateManager(managerAddress, {from: account});
    }).then(function() {
      self.setStatus("Transaction complete!");
    }).catch(function(e) {
      console.log(e);
      self.setStatus("Error sending coin; see log.");
    });
  },

  populateCreateManagerProposalsTable: function() {

    var self = this;

    var villageCoin;
    VillageCoin.deployed().then(function(instance) {
      villageCoin = instance;      
      return villageCoin.getMaxProposalId.call({from: account});
    }).then(function(maxProposalId) {
      console.log(maxProposalId.toNumber());
      var allProposalIds = [...Array(maxProposalId.toNumber()).keys()];
      console.log(allProposalIds);
      var promises = allProposalIds.map(function(id){ return villageCoin.getProposalBasicDetails.call(id, {from: account}) });
      return Promise.all(promises);    
    }).then(function(proposals){

      var promises = proposals
        .filter(function(proposal){ return filterProposalBasicDetailsByExistentAndType(proposal, ProposalType.CreateManager) })
        .map(function(proposal) { return villageCoin.getCreateManagerProposal.call(proposal[0], {from: account}) });

      return Promise.all(promises);      
    }).then(function(proposals){

      var html =       
        proposals
          .map(function(proposal){ return "<tr><td>" + proposal[0] + "</td><td>" + proposal[1] + "</td><td><button onclick='App.vote(" + proposal[0].toNumber() + ", true)'>YES</button><button onclick='App.vote(" + proposal[0].toNumber() + ", false)'>NO</button></td></tr>";})
          .reduce(function(accumulator, currentValue) { return accumulator + currentValue; }, "<tr><td>#</td><td>Address of Proposed Manager</td><td>Vote</td></tr>");

      document.getElementById("tableProposals").innerHTML = html;

    }).catch(function(e) {
      console.log(e);
      self.setStatus("Error fetching proposals; see log.");
    });
  },

  vote: function(proposalId, isYes) {
    var self = this;
    
    var villageCoin;
    VillageCoin.deployed().then(function(instance) {
      villageCoin = instance;      
      return villageCoin.voteOnProposal(proposalId, isYes, {from: account});
    }).then(function() {
      self.populateCreateManagerProposalsTable();
      self.setStatus("Your vote was recorded");   
    }).catch(function(e) {
      console.log(e);
      self.setStatus("Error voting; see log.");
    });  
  }
};

window.addEventListener('load', function() {
  // Checking if Web3 has been injected by the browser (Mist/MetaMask)
  if (typeof web3 !== 'undefined') {
    console.warn("Using web3 detected from external source. If you find that your accounts don't appear or you have 0 MetaCoin, ensure you've configured that source properly. If using MetaMask, see the following link. Feel free to delete this warning. :) http://truffleframework.com/tutorials/truffle-and-metamask")
    // Use Mist/MetaMask's provider
    window.web3 = new Web3(web3.currentProvider);
  } else {
    console.warn("No web3 detected. Falling back to http://localhost:8545. You should remove this fallback when you deploy live, as it's inherently insecure. Consider switching to Metamask for development. More info here: http://truffleframework.com/tutorials/truffle-and-metamask");
    // fallback - use your fallback strategy (local node / hosted node + in-dapp id mgmt / fail)
    window.web3 = new Web3(new Web3.providers.HttpProvider("http://localhost:8545"));
  }

  App.start();
});
