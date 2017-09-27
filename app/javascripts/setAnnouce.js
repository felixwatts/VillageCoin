'use strict';

const snoowrap = require('snoowrap');

const Web3 = require('web3');
const contract = require('truffle-contract');
const villagecoin_artifacts = require('../../build/contracts/VillageCoin.json');

var VillageCoin = contract(villagecoin_artifacts);

var accounts = {};
var account = undefined;

// Alternatively, just pass in a username and password for script-type apps.
const r = new snoowrap({
    userAgent: 'RVGatekeeper',
    clientId: 'tPx0Y0VgZ550QQ',
    clientSecret: global.process.env.RVGatekeeperClientSecret,
    username: 'RVGatekeeper',
    password: global.process.env.RVGatekeeperPassword,
  });

function setupWeb3Provider() 
{
    //Checking if Web3 has been injected by the browser (Mist/MetaMask)
    if (typeof web3 !== 'undefined') {
        console.warn("Using web3 detected from external source. If you find that your accounts don't appear or you have 0 MetaCoin, ensure you've configured that source properly. If using MetaMask, see the following link. Feel free to delete this warning. :) http://truffleframework.com/tutorials/truffle-and-metamask")
        // Use Mist/MetaMask's provider
        global.web3 = new Web3(web3.currentProvider);
    } else {
        console.warn("No web3 detected. Falling back to http://localhost:8545. You should remove this fallback when you deploy live, as it's inherently insecure. Consider switching to Metamask for development. More info here: http://truffleframework.com/tutorials/truffle-and-metamask");
        // fallback - use your fallback strategy (local node / hosted node + in-dapp id mgmt / fail)
        global.web3 = new Web3(new Web3.providers.HttpProvider("http://localhost:8545"));
    }

    VillageCoin.setProvider(web3.currentProvider); 
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
        
                accounts = accs;
                account = accounts[0];                                

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

async function run() 
{
    try
    {
        setupWeb3Provider();
        await setupAccounts();

        var contract = await VillageCoin.deployed();
        await contract.setAnnouncement("This is a public announcement. Please be aware that the network will be upagraded on 12/12/2018 meaning that all public account balances and transfers done after that time will be subject to bleh bleh.", {from: account, gas: 2000000});
    }
    catch(error)
    {
        console.log(error);
    }
}

run();