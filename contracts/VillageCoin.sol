pragma solidity ^0.4.9;

import "./SafeMathLib.sol";
import "./ParameterLib.sol";
import "./DemocracyLib.sol";
import "./TokenLib.sol";
import "./CitizenLib.sol";
import "./ProposalLib.sol";
import "./TaxLib.sol";

contract VillageCoin {

    using SafeMathLib for uint;
    using ParameterLib for ParameterLib.ParameterSet;
    using DemocracyLib for DemocracyLib.Referendum;
    using CitizenLib for CitizenLib.Citizenry;
    using TokenLib for TokenLib.TokenStorage;
    using ProposalLib for ProposalLib.ProposalSet;

    //
    // Fields
    //

    address public _gatekeeper;
    uint public _nextTaxTime;
    string public _announcementMessage; 

    ParameterLib.ParameterSet _parameters;
    TokenLib.TokenStorage _balances;
    CitizenLib.Citizenry public _citizens;
    ProposalLib.ProposalSet public _proposals;
    mapping(uint=>DemocracyLib.Referendum) public _referendums;

    //
    // Events
    //

    event OnProposalCreated(uint proposalId);
    event OnProposalDecided(uint proposalId);  

    //
    // Constructor 
    //        

    function VillageCoin() payable {        
        _gatekeeper = msg.sender;
    }

    //
    // Gatekeeper actions
    //

    function init() onlyGatekeeper public {

        _citizens.init();

        _parameters.addString("name", "RedditVillage");
        _parameters.addString("symbol", "RVX");
        _parameters.addNumber("decimals", 0, 0, 8);

        _parameters.addNumber("initialAccountBalance", 1000, 0, 0);
        _parameters.addNumber("proposalDecideThresholdPercent", 60, 0, 100);
        _parameters.addNumber("proposalTimeLimitDays", 30, 0, 0);
        _parameters.addNumber("citizenRequirementMinCommentKarma", 500, 100, 0);
        _parameters.addNumber("citizenRequirementMinPostKarma", 0, 0, 0);

        _parameters.addNumber("taxPeriodDays", 30, 1, 0);
        _parameters.addNumber("taxPollTax", 0, 0, 0);
        _parameters.addNumber("taxWealthTaxPercent", 0, 0, 100);
        _parameters.addNumber("taxBasicIncome", 0, 0, 0);
        _parameters.addNumber("taxTransactionTaxFlat", 0, 0, 0);
        _parameters.addNumber("taxTransactionTaxPercent", 0, 0, 100);
        _parameters.addNumber("taxProposalTaxFlat", 0, 0, 0);
        _parameters.addNumber("taxProposalTaxPercent", 0, 0, 100);        

        _nextTaxTime = now.plus(_parameters.getNumber("taxPeriodDays").times(1 days)); 
    }

    function setAnnouncement(string announcement) onlyGatekeeper public {
        _announcementMessage = announcement;
    }

    function selfDestruct() onlyGatekeeper public {
        selfdestruct(msg.sender);
    }

    function setGatekeeper(address newGatekeeper) public onlyGatekeeper {
        _gatekeeper = newGatekeeper;
    }

    function addCitizen(address addr, string redditUsername) onlyGatekeeper public {
        _citizens.add(addr, redditUsername);
        _balances.init(addr, _parameters.getNumber("initialAccountBalance"));
    }

    //
    // Public actions
    //

    function applyTaxesIfDue() public {
        var isDue = now > _nextTaxTime;
        if(!isDue) {
            return;
        }

        _nextTaxTime = _nextTaxTime.plus(getNumberParameter("taxPeriodDays").times(1 days)); 

        applyPollTax();
        applyWealthTax();

        applyBasicIncome();
    }

    function tryDecideProposal(uint proposalId) public {
        
        var referendum = _referendums[proposalId];

        var decision = referendum.tryDecide(_citizens.count, _parameters.getNumber("proposalDecideThresholdPercent"));

        if (decision == DemocracyLib.ReferendumState.Accepted) {
            enactProposal(proposalId);
        }
    }

    //
    // Citizen actions
    //

    function proposePackage(uint[] partIds, string supportingEvidence) public onlyCitizen {
        uint proposalId = _proposals.proposePackage(partIds, supportingEvidence);
        afterCreateProposal(proposalId);        
    }

    function proposeSetParameter (
        string parameterName,
        string stringValue,
        uint numberValue,
        string supportingEvidence,
        bool isPartOfPackage
    ) public onlyCitizen 
    {
        require(_parameters.isParameter(parameterName));
        uint proposalId = _proposals.proposeSetParameter(parameterName, stringValue, numberValue, supportingEvidence, isPartOfPackage);
        afterCreateProposal(proposalId);      
    }

    function proposeCreateMoney(uint amount, string supportingEvidence, bool isPartOfPackage) public onlyCitizen {
        uint proposalId = _proposals.proposeCreateMoney(amount, supportingEvidence, isPartOfPackage);
        afterCreateProposal(proposalId);
    }

    function proposeDestroyMoney(uint amount, string supportingEvidence, bool isPartOfPackage) public onlyCitizen {
        uint proposalId = _proposals.proposeDestroyMoney(amount, supportingEvidence, isPartOfPackage);
        afterCreateProposal(proposalId);
    }

    function proposePayCitizen(address citizen, uint amount, string supportingEvidence, bool isPartOfPackage) public onlyCitizen {
        require(_citizens.isCitizen(citizen));
        uint proposalId = _proposals.proposePayCitizen(citizen, amount, supportingEvidence, isPartOfPackage);
        afterCreateProposal(proposalId);
    }

    function proposeFineCitizen(address citizen, uint amount, string supportingEvidence, bool isPartOfPackage) public onlyCitizen {
        require(_citizens.isCitizen(citizen));
        uint proposalId = _proposals.proposeFineCitizen(citizen, amount, supportingEvidence, isPartOfPackage);        
        afterCreateProposal(proposalId);
    }

    function voteOnProposal(uint proposalId, bool isYes) public onlyCitizen {
        _referendums[proposalId].vote(msg.sender, isYes);
    }

    //
    // Views
    //

    function calculateProposalTax(address proposer) public constant returns(uint) {

        uint proposalTaxFlat = getNumberParameter("taxProposalTaxFlat");
        uint balance = balanceOf(proposer);
        uint proposalTaxPercent = getNumberParameter("taxProposalTaxPercent");

        return TaxLib.calculateProposalTax(proposalTaxFlat, proposalTaxPercent, balance);
    }

    function calculateTransactionTax(address from, address to, uint amount) public constant returns(uint) {
        uint transactionTaxFlat = _parameters.getNumber("taxTransactionTaxFlat");
        uint transactionTaxPercent = _parameters.getNumber("taxTransactionTaxPercent");

        return TaxLib.calculateTransactionTax(amount, from, to, transactionTaxFlat, transactionTaxPercent);
    }

    function getProposal(uint proposalId) public constant returns(
        ProposalLib.ProposalType typ, 
        address proposer, 
        bool isExistent,
        string stringParam1,
        string stringParam2,        
        uint numberParam1,              
        address addressParam1,                    
        string supportingEvidenceUrl,
        bool isPartOfPackage,
        bool isAssignedToPackage) 
        {

            ProposalLib.Proposal storage proposal = _proposals.proposals[proposalId];
        
            typ = proposal.typ;
            proposer = proposal.proposer;
            isExistent = proposal.isExistent;
            stringParam1 = proposal.stringParam1;
            stringParam2 = proposal.stringParam2;
            numberParam1 = proposal.numberParam1;
            addressParam1 = proposal.addressParam1;
            supportingEvidenceUrl = proposal.supportingEvidenceUrl;
            isPartOfPackage = proposal.isPartOfPackage;
            isAssignedToPackage = proposal.isAssignedToPackage;

            return;
    }

    function getItemsOfPackage(uint proposalId) public constant returns(uint[]) {
        return _proposals.proposals[proposalId].packageParts;
    }

    function getCitizenByUsername(string username) public constant returns(
        bool isExistent,
        address addr,
        uint balance)
    {
        CitizenLib.Citizen storage citizen = _citizens.citizenByUsername[username];

        isExistent = citizen.isExistent;
        addr = citizen.addr;
        balance = isExistent ? _balances.balances[addr] : 0;

        return;
    }

    function getCitizenByAddress(address addr) public constant returns(
        bool isExistent,
        string username,
        uint balance)
    {
        require(_citizens.isCitizen(addr));

        CitizenLib.Citizen storage citizen = _citizens.citizenByUsername[_citizens.usernameByAddress[addr]];

        isExistent = citizen.isExistent;
        username = citizen.username;
        balance = isExistent ? _balances.balances[addr] : 0;

        return;
    }

    function isNumberParameter(string name) public constant returns(bool) {
        return _parameters.isNumberParameter(name);
    }

    function isStringParameter(string name) public constant returns(bool) {
        return _parameters.isStringParameter(name);
    }

    function getNumberParameter(string name) public constant returns(uint current) {
        return _parameters.getNumber(name);
    }

    function getStringParameter(string name) public constant returns(string) {
        require(_parameters.isStringParameter(name));
        return _parameters.parameters[name].stringValue;
    }

    function isCitizen(address addr) public constant returns (bool) {
        return _citizens.isCitizen(addr);
    }

    function getHasSenderVoted(uint proposalId) returns(bool) {
        return _referendums[proposalId].hasVoted[msg.sender];
    }

    //
    // ERC20
    //

    event Transfer(address indexed from, address indexed to, uint amount);
  
    function transfer(address to, uint amount) public onlyCitizen returns (bool success) {
        require(_citizens.isCitizen(to));
        uint transactionTax = calculateTransactionTax(msg.sender, to, amount);
        _balances.transfer(msg.sender, TokenLib.getPublicAccount(), transactionTax);                
        _balances.transfer(msg.sender, to, amount);
    }

    function transferFrom(address from, address to, uint value) returns (bool success) {
        return false; // not supported
    }

    function balanceOf(address owner) constant returns (uint balance) {
        require(_citizens.isCitizen(owner));
        return _balances.balanceOf(owner);
    }

    function approve(address spender, uint value) returns (bool success) {
        return false; // not supported
    }

    function allowance(address owner, address spender) constant returns (uint remaining) {
        return 0; // not supported
    }

    function name() constant returns (string) {
        return _parameters.parameters["name"].stringValue;
    }

    function symbol() constant returns (string) {
        return _parameters.parameters["symbol"].stringValue;
    }

    function decimals() constant returns (uint8) {
        return uint8(_parameters.getNumber("decimals"));
    }

    function totalSupply() constant returns (uint256) {
        return _balances.totalSupply;
    }

    //
    // Internal Stuff
    //

    function afterCreateProposal(uint proposalId) private {
        bool isPartOfPackage = _proposals.proposals[proposalId].isPartOfPackage;
        if (isPartOfPackage) {
            return;
        }
        payProposalTax();
        _referendums[proposalId].init(_parameters.getNumber("proposalTimeLimitDays") * 1 days);
    }

    function payProposalTax() private {
        uint tax = calculateProposalTax(msg.sender);
        _balances.transfer(msg.sender, TokenLib.getPublicAccount(), tax);     
    }

    function enactProposal(uint proposalId) private {

        var proposal = _proposals.proposals[proposalId];
        assert(proposal.isExistent);

        if (proposal.typ == ProposalLib.ProposalType.SetParameter) {
                _parameters.set(proposal.stringParam1, proposal.stringParam2, proposal.numberParam1);
            } else if (proposal.typ == ProposalLib.ProposalType.CreateMoney) {
                _balances.createMoney(proposal.numberParam1);
            } else if (proposal.typ == ProposalLib.ProposalType.DestroyMoney) {
                _balances.destroyMoney(proposal.numberParam1);        
            } else if (proposal.typ == ProposalLib.ProposalType.PayCitizen) {
                payCitizen(proposal.addressParam1, proposal.numberParam1);
            } else if (proposal.typ == ProposalLib.ProposalType.FineCitizen) {
                fineCitizen(proposal.addressParam1, proposal.numberParam1);
            } else if (proposal.typ == ProposalLib.ProposalType.Package) {
                for (uint i = 0; i < proposal.packageParts.length; i++) {
                    enactProposal(proposal.packageParts[i]);
                }
            } else {
                revert();
            }
    }

    function applyPollTax() private {
        var pollTaxAmount = _parameters.getNumber("taxPollTax");
        if (pollTaxAmount == 0) {
            return;
        }

        for (_citizens.iterateStart(); _citizens.iterateValid(); _citizens.iterateNext()) {
            var citizen = _citizens.iterateCurrent();
            _balances.transferAsMuchAsPossibleOf(citizen, TokenLib.getPublicAccount(), pollTaxAmount);
        }
    }

    function applyWealthTax() private {

        var wealthTaxPercent = _parameters.getNumber("taxWealthTaxPercent");
        if (wealthTaxPercent == 0) {
            return;
        }

        for (_citizens.iterateStart(); _citizens.iterateValid(); _citizens.iterateNext()) {
            var citizen = _citizens.iterateCurrent();
            var wealthTaxAmount = TaxLib.calculateWealthTax(_balances.balanceOf(citizen), wealthTaxPercent);
            _balances.transfer(citizen, TokenLib.getPublicAccount(), wealthTaxAmount); 
        }
    }

    function applyBasicIncome() private {
        var basicIncomeAmount = _parameters.getNumber("taxBasicIncome");
        if (basicIncomeAmount == 0) {
            return;
        }

        var totalValue = basicIncomeAmount.times(_citizens.count);
        var publicFunds = _balances.balanceOf(TokenLib.getPublicAccount());
        if (totalValue > publicFunds) {
            basicIncomeAmount = publicFunds / _citizens.count;
        }

        for (_citizens.iterateStart(); _citizens.iterateValid(); _citizens.iterateNext()) {
            var citizen = _citizens.iterateCurrent();
            _balances.transfer(TokenLib.getPublicAccount(), citizen, basicIncomeAmount);  
        }
    }

    function payCitizen(address citizen, uint amount) private {
        assert(isCitizen(citizen));
        _balances.transferAsMuchAsPossibleOf(TokenLib.getPublicAccount(), citizen, amount);
    }

    function fineCitizen(address citizen, uint amount) private {
        assert(isCitizen(citizen));
        _balances.transferAsMuchAsPossibleOf(citizen, TokenLib.getPublicAccount(), amount);
    }

    modifier onlyCitizen {
        require(isCitizen(msg.sender));
        _;
    }

    modifier onlyGatekeeper {
        require(msg.sender == _gatekeeper);
        _;
    }
}