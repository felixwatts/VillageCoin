// Import the page's CSS. Webpack will know what to do with it.
import "../stylesheets/app.css";

// Import libraries we need.
import { default as Web3 } from 'web3';
import { default as contract } from 'truffle-contract';

// Import our contract artifacts and turn them into usable abstractions.
import spawner_artifacts from '../../build/contracts/Spawner.json';
import villagecoin_artifacts from '../../build/contracts/VillageCoin.json';

// VillageCoin is our usable abstraction, which we'll use through the code below.
var Spawner = contract(spawner_artifacts);
var VillageCoin = contract(villagecoin_artifacts);

function setStatus (message) 
{
    var status = document.getElementById("status");
    status.innerHTML = message;
    status.style.visibility = "visible";
}

function setupWeb3Provider() 
{
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

    Spawner.setProvider(web3.currentProvider);
    VillageCoin.setProvider(web3.currentProvider); 
}

function parseQueryString(url) 
{
    var urlParams = {};
    url.replace(
        new RegExp("([^?=&]+)(=([^&]*))?", "g"),
        function($0, $1, $2, $3) {
        urlParams[$1] = $3;
        }
    );
    
    return urlParams;
}

function getContractAddress() 
{
    var url = location.search;  
    var urlParameters = parseQueryString(url);
    var contractAddress = urlParameters.contractAddress;
    var isValidAddress = web3.isAddress(contractAddress);
    if(!isValidAddress) throw("invalid contract address");

    return contractAddress;
}

function setupAccounts()
{
    var promise = new Promise(function(resolve, reject) 
    {
        try 
        {        
            // Get the initial account balance so it can be displayed.
            web3.eth.getAccounts(function(err, accs) 
            {
                if (err != null) {
                    throw("There was an error fetching your accounts.");
                }
        
                if (accs.length == 0) 
                {
                    throw("Couldn't get any accounts! Make sure your Ethereum client is configured correctly.")
                }
        
                window.app.accounts = accs;
                window.app.account = window.app.accounts[0];

                resolve();
            });
        } 
        catch(error)
        {
            reject(error);
        }
    });

    return promise;
}

async function redirectNonCitizen()
{
    var villageCoin = app.contract;
    var isCitizen = await villageCoin.isCitizen.call(window.app.account);

    if(!isCitizen) window.location.replace("welcome.html?contractAddress=" + villageCoin.address);
}

async function redirectCitizen()
{
    var villageCoin = app.contract;
    var isCitizen = await villageCoin.isCitizen.call(window.app.account);

    if(isCitizen) window.location.replace("villageIndex.html?contractAddress=" + villageCoin.address);
}

async function redirectNonGatekeeper()
{
    var villageCoin = app.contract;
    var isGatekeeper = await villageCoin.isGatekeeper(window.app.account);

    if(!isGatekeeper) window.location.replace("villageIndex.html?contractAddress=" + villageCoin.address);
}

async function populateVillageName()
{
    var villageName = await getVillageName();

    var villageNameElements = document.getElementsByClassName("villageName");

    for (var i = 0; i < villageNameElements.length; i++) 
    {
        villageNameElements[i].innerHTML = villageName;
    }    
}

async function populateVillageSymbol()
{
    var villageSymbol= await getVillageSymbol();

    var villageSymbolElements = document.getElementsByClassName("villageSymbol");

    for (var i = 0; i < villageSymbolElements.length; i++) 
    {
        villageSymbolElements[i].innerHTML = villageSymbol;
    }    
}

async function getVillageName() 
{
    var villageCoin = app.contract;
    var villageName = await villageCoin.name.call({from: app.account});
    return villageName;
}

async function getVillageSymbol() 
{
    var villageCoin = app.contract;
    var symbol = await villageCoin.symbol.call({from: app.account});
    return symbol;
}

async function getProposalDescription(proposalId)
{
    var villageCoin = app.contract;

    var proposalBasicDetails = await villageCoin.getProposalBasicDetails.call(proposalId, {from: app.account});
    var isExistent = proposalBasicDetails[1];
    var decision = proposalBasicDetails[2].toNumber();            
    var hasSenderVoted = proposalBasicDetails[3];
    var proposalType = proposalBasicDetails[4].toNumber(); 
    var expiryTime = proposalBasicDetails[5].toNumber(); 

    var description = "";

    switch(proposalType)
    {
        case app.ProposalType.AppointGatekeeper:
        {
            var details = await villageCoin.getAppointGatekeeperProposal.call(proposalId, {from: app.account});
            var gatekeeperAddress = details[1];
            description = "appoint <strong>" + gatekeeperAddress + "</strong> as a <strong>gatekeeper</strong>";
        }
        break;
        case app.ProposalType.AddCitizen:
        {
            var details = await villageCoin.getAddCitizenProposal.call(proposalId, {from: app.account});
            var citizenAddress = details[1];
            description = "allow the owner of address <strong>" + citizenAddress + "</strong> to become a <strong>citizen</strong>";
        }
        break;
    }

    return description
}

async function populateVillageMenu()
{
    document.getElementById("menuHome").href = "villageIndex.html?contractAddress=" + app.contract.address;
    document.getElementById("menuProposals").href = "proposals.html?contractAddress=" + app.contract.address;
    document.getElementById("menuCreateProposal").href = "createProposal.html?contractAddress=" + app.contract.address;
}

function setupCommonFunctions() 
{
    window.app.VillageCoin = VillageCoin;

    window.app.getVillageName = getVillageName;
    window.app.getVillageSymbol = getVillageSymbol;
    window.app.parseQueryString = parseQueryString;
    window.app.initVillage = initVillage;
    window.app.setStatus = setStatus;
    window.app.redirectCitizen = redirectCitizen;
    window.app.redirectNonCitizen = redirectNonCitizen;
    window.app.redirectNonGatekeeper = redirectNonGatekeeper;
    window.app.getProposalDescription = getProposalDescription;
    window.app.populateVillageName = populateVillageName;
    window.app.populateVillageSymbol = populateVillageSymbol;

    var ProposalType = {};
    ProposalType.AppointGatekeeper = 0; 
    ProposalType.DismissGatekeeper = 1; 
    ProposalType.AddCitizen = 2; 
    ProposalType.RemoveCitizen = 3; 
    ProposalType.SetContractParameters = 4; 
    ProposalType.CreateMoney = 5;
    ProposalType.TaxWealth = 6; 
    ProposalType.SpendPublicMoney = 7;
    window.app.ProposalType = ProposalType;

    var ProposalDecision = {};
    ProposalDecision.Undecided = 0;
    ProposalDecision.Accepted = 1;
    ProposalDecision.Rejected = 2;
    ProposalDecision.Expired = 3;
    window.app.ProposalDecision = ProposalDecision;
}

async function initVillage()
{
    try
    {        
        var contractAddress = getContractAddress();
        window.app.contract = await app.VillageCoin.at(contractAddress);  

        populateVillageName();
        populateVillageSymbol();
        populateVillageMenu();
    }
    catch(error)
    {
        window.location.replace("index.html");
    }
} 

window.init = async function()
{
    window.app = {};
    
    setupWeb3Provider();
    await setupAccounts();
    setupCommonFunctions();
    
    window.app.spawner = await Spawner.deployed();
};