pragma solidity ^0.4.9;

import "./SafeMathLib.sol";
import "./TokenLib.sol";

// Some pure fuctions for calcuating tax amounts due for different types of tax
library TaxLib {

    using SafeMathLib for uint;

    function calculateProposalTax(uint taxProposalTaxFlat, uint taxProposalTaxPercent, uint proposerBalance) public constant returns(uint) {        
        return taxProposalTaxFlat.plus(taxProposalTaxPercent.times(proposerBalance) / 100);
    }

    function calculateTransactionTax(uint amount, address from, address to, uint taxTransactionTaxFlat, uint taxTransactionTaxPercent) public constant returns(uint) {
        uint transactionTaxTotal = 0;
        
        if (from != TokenLib.getPublicAccount() && to != TokenLib.getPublicAccount()) {
            transactionTaxTotal = taxTransactionTaxFlat.plus(taxTransactionTaxPercent.times(amount) / 100);
        }

        return transactionTaxTotal;
    }

    function calculateWealthTax(uint balance, uint wealthTaxPercent) public constant returns(uint) {
        return balance.times(wealthTaxPercent) / 100;        
    }
}