// Import the page's CSS. Webpack will know what to do with it.
import "../stylesheets/app.css";

// Import libraries we need.
import { default as Web3 } from 'web3';
import { default as contract } from 'truffle-contract'

// Import our contract artifacts and turn them into usable abstractions.
import villagecoin_artifacts from '../../build/contracts/VillageCoin.json'

// VillageCoin is our usable abstraction, which we'll use through the code below.
var VillageCoin = contract(villagecoin_artifacts);

function setStatus (message) {
    var status = document.getElementById("status");
    status.innerHTML = message;
}

function setupWeb3Provider() {
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
}

function setupContract() {
    // Bootstrap the VillageCoin abstraction for Use.
    VillageCoin.setProvider(web3.currentProvider);

    window.app.contract = VillageCoin;

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

        window.app.accounts = accs;
        window.app.account = window.app.accounts[0];
    });
}

function setupCommonFunctions() {
    window.app.setStatus = setStatus;

    var ProposalType = {};
    ProposalType.CreateManager = 0; 
    ProposalType.DeleteManager = 1; 
    ProposalType.CreateAccount = 2; 
    ProposalType.DeleteAccount = 3; 
    ProposalType.SetContractParameters = 4; 
    ProposalType.CreateMoney = 5;
    ProposalType.TaxWealth = 6; 
    ProposalType.SpendPublicMoney = 7;
    window.app.ProposalType = ProposalType;
}

window.addEventListener('load', function() {

    window.app = {};

    setupWeb3Provider();
    setupContract(); 
    setupCommonFunctions();   
});