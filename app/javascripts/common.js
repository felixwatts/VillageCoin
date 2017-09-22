import "../stylesheets/app.css";

import { default as Web3 } from 'web3';
import { default as contract } from 'truffle-contract';

var BigNumber = require('bignumber.js');
var validUrl = require('valid-url');

import villagecoin_artifacts from '../../build/contracts/VillageCoin.json';

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

function setupAccounts()
{
    var promise = new Promise(function(resolve, reject) 
    {
        try 
        {        
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

    if(!isCitizen) window.location.replace("welcome.html");
}

async function redirectCitizen()
{
    var villageCoin = app.contract;
    var isCitizen = await villageCoin.isCitizen.call(window.app.account);

    if(isCitizen) window.location.replace("index.html");
}

async function populateRedditUsername()
{
    var redditUsername = (await app.contract._citizens.call(app.account))[3];

    var redditUsernameElements = document.getElementsByClassName("redditUsername");

    for (var i = 0; i < redditUsernameElements.length; i++) 
    {
        redditUsernameElements[i].innerHTML = redditUsername;
    }    
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
    var villageSymbol = await getVillageSymbol();

    var villageSymbolElements = document.getElementsByClassName("villageSymbol");

    for (var i = 0; i < villageSymbolElements.length; i++) 
    {
        villageSymbolElements[i].innerHTML = villageSymbol;
    }    
}

async function getVillageName() 
{
    var villageName = await app.contract.name.call({from: app.account});
    return villageName;
}

async function getVillageSymbol() 
{
    var symbol = await app.contract.symbol.call({from: app.account});
    return symbol;
}

async function getProposal(proposalId) 
{
    var data = await app.contract._proposals.call(proposalId, {from: app.account});

    var proposal = 
    {
        id: proposalId,
        type: data[0].toNumber(),
        voteCountYes: data[1].toNumber(),
        voteCountNo: data[2].toNumber(),
        proposer: data[3],
        isExistent: data[4],
        decision: data[5].toNumber(),
        expiryTime: data[6],
        supportingEvidenceUrl: data[11]       
    };

    switch(proposal.type)
    {
        case app.ProposalType.SetParameter:
            proposal.parameterName = data[7];
            proposal.stringValue = data[8];
            proposal.numberValue = data[9].toNumber();
            break;

        case app.ProposalType.CreateMoney:
            proposal.amount = data[9].toNumber();
            break;

        case app.ProposalType.DestroyMoney:
            proposal.amount = data[9].toNumber();
            break;

        case app.ProposalType.PayCitizen:
            proposal.citizen = data[10];
            proposal.amount = data[9].toNumber();
            break;

        case app.ProposalType.FineCitizen:
            proposal.citizen = data[10];
            proposal.amount = data[9].toNumber();
            break;
    }

    return proposal;
}

async function getCitizen(addr)
{
    var data = await app.contract._citizens.call(addr, {from: app.account});

    var citizen = 
    {
        address: data[0],
        balance: data[1].toNumber(),
        isExistent: data[2],
        redditUsername: data[3]
    };

    return citizen;
}

async function formatCurrencyAmount(amount)
{
    var decimals = await app.contract.decimals.call({from: app.account});
    var symbol = await app.contract.symbol.call({from: app.account});

    return new BigNumber(10).pow(decimals.negated()).mul(amount).toFormat(decimals) + " " + symbol;
}

async function parseCurrencyAmount(amountStr)
{
    var x = parseFloat(amountStr);
    console.log(x);

    if(isNaN(parseFloat(amountStr))) return NaN;

    var decimals = await app.contract.decimals.call({from: app.account});
    return new BigNumber(10).pow(decimals).mul(parseFloat(amountStr)).toNumber();
}

async function getProposalDescription(proposalId)
{
    var proposal = await getProposal(proposalId);

    var description = "";

    switch(proposal.type)
    { 
        case app.ProposalType.SetParameter:
        {
            var isNumberParameter = await app.contract.isNumberParameter(proposal.parameterName);
            var parameterValue = isNumberParameter ? proposal.numberValue : proposal.stringValue;
            return "set parameter <strong>" + proposal.parameterName + "</strong> to <strong>" + parameterValue + "</strong>";
        }
        break;

        case app.ProposalType.CreateMoney:
        {
            var amountStr = await formatCurrencyAmount(proposal.amount);
            return "create <strong>" + amountStr + "</strong> and add it to the public account";
        }
        break;

        case app.ProposalType.DestroyMoney:
        {
            var amountStr = await formatCurrencyAmount(proposal.amount);
            return "take <strong>" + amountStr + "</strong> from the public account balance and <strong>destroy</strong> it";
        }
        break;

        case app.ProposalType.PayCitizen:
        {
            var citizen = await getCitizen(proposal.citizen);
            var amountStr = await formatCurrencyAmount(proposal.amount);

            return "transfer <strong>" + amountStr + "</strong> from the public account to citizen <strong>" + citizen.redditUsername + "</strong>";
        }
        break;

        case app.ProposalType.FineCitizen:
        {            
            var citizen = await getCitizen(proposal.citizen);
            var amountStr = await formatCurrencyAmount(proposal.amount);

            return "transfer <strong>" + amountStr + "</strong> from citizen <strong>" + citizen.redditUsername + "</strong> to the public account";
        }
        break;
    }

    return description
}

function filterProposalByUndecided(proposal) 
{
    return proposal.isExistent && proposal.decision == app.ProposalDecision.Undecided;
}

async function getUndecidedProposals() 
{
    var villageCoin = app.contract;
    var maxProposalId = await villageCoin._nextProposalId.call({from: app.account});
    var allProposalIds = [...Array(maxProposalId.toNumber()).keys()];
    var allProposals = await Promise.all(allProposalIds.map(function(id){ return getProposal(id);}));

    var votableProposals = allProposals.filter(filterProposalByUndecided);
    
    return votableProposals;
}

async function validateForm()
{
    var validationErrors = [];
    var results = {};

    var addressInputs = document.getElementsByClassName("inputAddress");
    for(var i = 0; i < addressInputs.length; i++)
    {
        await validateAddressInput(addressInputs[i], validationErrors, results); // todo make parallel
    }

    var amountInputs = document.getElementsByClassName("inputAmount");
    for(var i = 0; i < amountInputs.length; i++)
    {
        await validateAmountInput(amountInputs[i], validationErrors, results); // todo make parallel
    }

    var urlInputs = document.getElementsByClassName("inputUrl");
    for(var i = 0; i < urlInputs.length; i++)
    {
        await validateUrlInput(urlInputs[i], validationErrors, results); // todo make parallel
    }

    if(validationErrors.length != 0)
    {
        results.isValid = false;
        results.errorMessage = validationErrors.reduce(function(head, tail){ return head + "<br>" + tail});
    }
    else
    {
        results.isValid = true;
    }

    var submitButton = document.getElementById("inputSubmit");
    submitButton.disabled = !results.isValid;
    var inputInvalidMessage = document.getElementById("inputInvalidMessage");
    inputInvalidMessage.innerHTML = results.isValid ? "" : results.errorMessage;

    return results;
}

async function validateAmountInput(element, validationErrors, results)
{
    var amountStr = element.value;

    var amount = await parseCurrencyAmount(amountStr);

    if(isNaN(amount))
    {
        validationErrors.push("Invalid currency amount")
    }
    else
    {
        results[element.id] = amount;
    }
}

async function validateAddressInput(element, validationErrors, results)
{
    var addressStr = element.value;

    if(addressStr == undefined || addressStr == "")
    {
        validationErrors.push("You must specify a citizen");
        return;
    }

    var isValidAddress = web3.isAddress(addressStr);
    if(isValidAddress)
    {            
        var isCitizen = await app.contract.isCitizen.call(toAddress, amount, {from: app.account});
        if(!isCitizen)
        {
            validationErrors.push(addressStr + " is not a citizen");
        }
        else
        {
            results[element.id] = addressStr;
        }
    }
    else
    {
        var address = await app.contract.getAddressOfRedditUsername(addressStr, {from: app.account});
        
        if(address == "0x0000000000000000000000000000000000000000")
        {
            validationErrors.push(addressStr + " is not a citizen");
        }
        else
        {            
            results[element.id] = address;
        }
    }  
}

async function validateUrlInput(element, validationErrors, results)
{
    var urlStr = element.value;
    if(urlStr == undefined || urlStr == "") return;

    if(validUrl.isWebUri(urlStr))
    {
        results[element.id] = urlStr;
    }
    else
    {
        validationErrors.push("Invalid URL");
    }
}

function setupCommonFunctions() 
{
    window.app.VillageCoin = VillageCoin;

    window.app.validateForm = validateForm;
    window.app.parseCurrencyAmount = parseCurrencyAmount;
    window.app.formatCurrencyAmount = formatCurrencyAmount;
    window.app.getCitizen = getCitizen;
    window.app.populateRedditUsername = populateRedditUsername;
    window.app.getProposal = getProposal;
    window.app.getVillageName = getVillageName;
    window.app.getVillageSymbol = getVillageSymbol;
    window.app.parseQueryString = parseQueryString;
    window.app.setStatus = setStatus;
    window.app.redirectCitizen = redirectCitizen;
    window.app.redirectNonCitizen = redirectNonCitizen;
    window.app.getProposalDescription = getProposalDescription;
    window.app.populateVillageName = populateVillageName;
    window.app.populateVillageSymbol = populateVillageSymbol;
    window.app.getUndecidedProposals = getUndecidedProposals;

    var ProposalType = {};
    ProposalType.SetParameter = 0; 
    ProposalType.CreateMoney = 1;
    ProposalType.DestroyMoney = 2;
    ProposalType.PayCitizen = 3; 
    ProposalType.FineCitizen = 4;
    window.app.ProposalType = ProposalType;

    var ProposalDecision = {};
    ProposalDecision.Undecided = 0;
    ProposalDecision.Accepted = 1;
    ProposalDecision.Rejected = 2;
    ProposalDecision.Expired = 3;
    window.app.ProposalDecision = ProposalDecision;
}

window.init = async function()
{
    window.app = {};
    
    setupWeb3Provider();
    await setupAccounts();
    setupCommonFunctions();
    
    window.app.contract = await VillageCoin.deployed();
    
    populateVillageName();
    populateVillageSymbol();
};