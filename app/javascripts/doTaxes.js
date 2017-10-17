'use strict';

const Web3 = require('web3');
const contract = require('truffle-contract');
const villagecoin_artifacts = require('../../build/contracts/VillageCoin.json');

var VillageCoin = contract(villagecoin_artifacts);

var accounts = {};
var account = undefined;

function setupWeb3Provider() 
{
    global.web3 = new Web3(new Web3.providers.HttpProvider("http://localhost:8545"));
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

        var rcpt = await contract.applyTaxesIfDue({from: account, gas: 6700000});
        console.log(rcpt);
        console.log(rcpt.logs[0]);
    }
    catch(error)
    {
        console.log(error);
    }
}

run();