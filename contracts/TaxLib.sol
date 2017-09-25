pragma solidity ^0.4.9;

import "./SafeMathLib.sol";
import "./ParameterLib.sol";
import "./TokenLib.sol";

library TaxLib {

    using SafeMathLib for uint;
    using ParameterLib for ParameterLib.ParameterSet;
    using TokenLib for TokenLib.TokenStorage;

    function calculateProposalTax(address proposer, uint taxProposalTaxFlat, uint taxProposalTaxPercent, uint proposerBalance) public constant returns(uint) {        
        return taxProposalTaxFlat.plus(taxProposalTaxPercent.times(proposerBalance) / 100);
    }

    function calculateTransactionTax(uint amount, address from, address to, uint taxTransactionTaxFlat, uint taxTransactionTaxPercent) public constant returns(uint) {
        uint transactionTaxTotal = 0;
        
        if (from != TokenLib.PUBLIC_ACCOUNT && to != TokenLib.PUBLIC_ACCOUNT) {
            transactionTaxTotal = taxTransactionTaxFlat.plus(taxTransactionTaxPercent.times(amount) / 100);
        }

        return transactionTaxTotal;
    }

    function calculateWealthTax(uint balance, uint wealthTaxPercent) public constant returns(uint) {
        return balance.times(wealthTaxPercent) / 100;        
    }
}