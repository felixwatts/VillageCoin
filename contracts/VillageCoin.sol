pragma solidity ^0.4.9;

import "./SafeMathLib.sol";
import "./ParameterLib.sol";
import "./ReferendumLib.sol";
import "./TokenLib.sol";
import "./CitizenLib.sol";
import "./ProposalLib.sol";
import "./TaxLib.sol";
import "./Storage.sol";

// This is the main contract
// VillageCoin implments a 'Democratic Currency' which has the following main features:
// - It's an ERC20 token
//
// - To receive or send funds a user must first create an account
// - Account creation is controlled by a priviliged user called the 'gatekeeper'
// - It is the gatekeeper's job to ensure that each human can have at most one account
//
// - Monetary and fiscal policy of the currency is determined democratically by the users on a one account (person) one vote basis
contract VillageCoin {

    using SafeMathLib for uint;
    using ReferendumLib for ReferendumLib.Referendum;
    using CitizenLib for CitizenLib.Citizens;
    using TokenLib for TokenLib.Tokens;
    using ProposalLib for ProposalLib.Proposals;

    //
    // Constants
    //

    bytes32 constant public PRM_NAME = sha3("PRM_NAME");
    bytes32 constant public PRM_DECIMALS = sha3("PRM_DECIMALS");
    bytes32 constant public PRM_INITIAL_ACCOUNT_BALANCE = sha3("PRM_INITIAL_ACCOUNT_BALANCE");
    bytes32 constant public PRM_TAX_PERIOD_DAYS = sha3("PRM_TAX_PERIOD_DAYS");
    bytes32 constant public PRM_PROPOSAL_DECIDE_THRESHOLD_PERCENT = sha3("PRM_PROPOSAL_DECIDE_THRESHOLD_PERCENT");
    bytes32 constant public PRM_PROPOSAL_TAX_FLAT = sha3("PRM_PROPOSAL_TAX_FLAT");
    bytes32 constant public PRM_PROPOSAL_TAX_PERCENT = sha3("PRM_PROPOSAL_TAX_PERCENT");
    bytes32 constant public PRM_TRANSACTION_TAX_FLAT = sha3("PRM_TRANSACTION_TAX_FLAT");
    bytes32 constant public PRM_TRANSACTION_TAX_PERCENT = sha3("PRM_TRANSACTION_TAX_PERCENT");
    bytes32 constant public PRM_PROPOSAL_TIME_LIMIT_DAYS = sha3("PRM_PROPOSAL_TIME_LIMIT_DAYS");
    bytes32 constant public PRM_POLL_TAX = sha3("PRM_POLL_TAX");
    bytes32 constant public PRM_WEALTH_TAX_PERCENT = sha3("PRM_WEALTH_TAX_PERCENT");
    bytes32 constant public PRM_BASIC_INCOME = sha3("PRM_BASIC_INCOME");

    //
    // Fields
    //

    Storage _storage;

    // The address of the priviliged user that can create accounts and do some other special things
    address public _gatekeeper;
    // Next round of taxes cannot be applied before this time
    uint public _nextTaxTime;
    // A message to display at the top of the website for special annoucements etc.
    string public _announcementMessage; 

    // Each citizen's token balance
    TokenLib.Tokens _tokens;
    // The address and username of each registered citizen (account owner)
    CitizenLib.Citizens public _citizens;
    // Proposals that have been made by citizens
    ProposalLib.Proposals public _proposals;
    // Referendums on proposals, keyed by proposal ID
    mapping(uint=>ReferendumLib.Referendum) public _referendums;

    //
    // Events
    //

    event OnProposalCreated(uint proposalId);
    //event OnProposalDecided(uint proposalId);  

    //
    // Constructor 
    //        

    function VillageCoin() payable {        
        _gatekeeper = msg.sender;
    }

    //
    // Gatekeeper actions
    //

    // Called once by the gatekeeper after deploying the contract
    // Initializes the contract with some required state
    function init(address storageAddr) onlyGatekeeper public {

        _storage = Storage(storageAddr);
        _citizens.init();
    }

    function addStringParameter(bytes32 name, bytes32 initialValue) onlyGatekeeper public {
        ParameterLib.addString(_storage, name, initialValue);
    }

    function addNumberParameter (bytes32 name, uint initialValue, uint min, uint max) onlyGatekeeper public {
        ParameterLib.addNumber(_storage, name, initialValue, min, max);
    }

    // Set the announcement message at the top of the website
    function setAnnouncement(string announcement) onlyGatekeeper public {
        _announcementMessage = announcement;
    }

    // Kill this contract
    function selfDestruct() onlyGatekeeper public {
        selfdestruct(msg.sender);
    }

    // Change the gatekeeper's address. Not sure why this would be needed :/
    function setGatekeeper(address newGatekeeper) public onlyGatekeeper {
        _gatekeeper = newGatekeeper;
    }

    // Create a new citizen account
    // This should only be called after verifying that the applicant is a real person and that they do not already own an account, this check prevents sybil attacks on the democracy and basic income systems
    // Throws if the username or the address already belong to a citizen
    // Gives the new citizen some funds to start with
    function addCitizen(address addr, string redditUsername) onlyGatekeeper public {
        _citizens.add(addr, redditUsername);
        _tokens.init(addr, getNumberParameter(PRM_INITIAL_ACCOUNT_BALANCE));
    }

    //
    // Public actions
    //

    // If taxes are now due then take/give all taxes, otherwise do nothing
    function applyTaxesIfDue() public {
        var isDue = now > _nextTaxTime;
        if (!isDue) {
            return;
        }

        _nextTaxTime = _nextTaxTime.plus(getNumberParameter(PRM_TAX_PERIOD_DAYS).times(1 days)); 

        applyPollTax();
        applyWealthTax();

        applyBasicIncome();
    }

    // Check the referendum on the given proposal and implement the proposed changes if the referendum has been Accepted
    // Throws if the referendum is not currently Undecided
    // Changes the state of the referendum from Undecided to Accepted or Rejected if any of the respective conditions are met
    // Enacts the changes of the proposal if it is newly Accepted
    function tryDecideProposal(uint proposalId) public {
        
        var referendum = _referendums[proposalId];

        var decision = referendum.tryDecide(_citizens.count, getNumberParameter(PRM_PROPOSAL_DECIDE_THRESHOLD_PERCENT));

        if (decision == ReferendumLib.ReferendumState.Accepted) {
            enactProposal(proposalId);
        }
    }

    //
    // Citizen actions
    //

    // See ProposalLib.sol
    function proposePackage(uint[] partIds, bytes32 supportingEvidence) public onlyCitizen {
        uint proposalId = _proposals.proposePackage(partIds, supportingEvidence);
        afterCreateProposal(proposalId);        
    }

    // See ProposalLib.sol
    function proposeSetParameter (
        bytes32 parameterName,
        bytes32 stringValue,
        uint numberValue,
        bytes32 supportingEvidence,
        bool isPartOfPackage
    ) public onlyCitizen 
    {
        // throw if it is not legal to set this parameter to this value
        ParameterLib.validateValue(_storage, parameterName, stringValue, numberValue);

        uint proposalId = _proposals.proposeSetParameter(parameterName, stringValue, numberValue, supportingEvidence, isPartOfPackage);
        afterCreateProposal(proposalId);      
    }

    // See ProposalLib.sol
    function proposeCreateMoney(uint amount, bytes32 supportingEvidence, bool isPartOfPackage) public onlyCitizen {
        uint proposalId = _proposals.proposeCreateMoney(amount, supportingEvidence, isPartOfPackage);
        afterCreateProposal(proposalId);
    }

    // See ProposalLib.sol
    function proposeDestroyMoney(uint amount, bytes32 supportingEvidence, bool isPartOfPackage) public onlyCitizen {
        uint proposalId = _proposals.proposeDestroyMoney(amount, supportingEvidence, isPartOfPackage);
        afterCreateProposal(proposalId);
    }

    // See ProposalLib.sol
    function proposePayCitizen(address citizen, uint amount, bytes32 supportingEvidence, bool isPartOfPackage) public onlyCitizen {
        require(_citizens.isCitizen(citizen));
        uint proposalId = _proposals.proposePayCitizen(citizen, amount, supportingEvidence, isPartOfPackage);
        afterCreateProposal(proposalId);
    }

    // See ProposalLib.sol
    function proposeFineCitizen(address citizen, uint amount, bytes32 supportingEvidence, bool isPartOfPackage) public onlyCitizen {
        require(_citizens.isCitizen(citizen));
        uint proposalId = _proposals.proposeFineCitizen(citizen, amount, supportingEvidence, isPartOfPackage);        
        afterCreateProposal(proposalId);
    }
    
    // See ReferendumLib.sol
    function voteOnProposal(uint proposalId, bool isYes) public onlyCitizen {
        _referendums[proposalId].vote(msg.sender, isYes);
    }

    //
    // Views
    //

    function getCitizen(uint id) public constant returns (string username, address addr, bool isExistent) {
        username = _citizens.citizens[id].username;
        addr = _citizens.citizens[id].addr;
        isExistent = _citizens.citizens[id].isExistent;
    }

    function isCitizen(address addr) public constant returns(bool) {
        return _citizens.isCitizen(addr);      
    }

    // Return the tax due if the specified Citizen makes a proposal
    function calculateProposalTax(address proposer) public constant returns(uint) {

        uint proposalTaxFlat = getNumberParameter(PRM_PROPOSAL_TAX_FLAT);
        uint balance = _tokens.balanceOf(proposer);
        uint proposalTaxPercent = getNumberParameter(PRM_PROPOSAL_TAX_PERCENT);

        return TaxLib.calculateProposalTax(proposalTaxFlat, proposalTaxPercent, balance);
    }

    // Return the tax due if the specified Citizen makes the specified transaction
    function calculateTransactionTax(address from, address to, uint amount) public constant returns(uint) {
        uint transactionTaxFlat = getNumberParameter(PRM_TRANSACTION_TAX_FLAT);
        uint transactionTaxPercent = getNumberParameter(PRM_TRANSACTION_TAX_PERCENT);

        return TaxLib.calculateTransactionTax(amount, from, to, transactionTaxFlat, transactionTaxPercent);
    }

    // Return all details of specified proposal
    function getProposal(uint proposalId) public constant returns(
        ProposalLib.ProposalType typ, 
        address proposer, 
        bool isExistent,
        bytes32 stringParam1,
        bytes32 stringParam2,        
        uint numberParam1,              
        address addressParam1,                    
        bytes32 supportingEvidenceUrl,
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

    // Return ids of Parts of specified Proposal
    function getItemsOfPackage(uint proposalId) public constant returns(uint[]) {
        // Annoyingly cant return _proposals.getItemsOfPackage(proposalId)
        require(_proposals.proposals[proposalId].isExistent);
        require(_proposals.proposals[proposalId].typ == ProposalLib.ProposalType.Package);
        return _proposals.proposals[proposalId].packageParts;
    }

    // Return all details of citizen with specified username
    // Doesnt throw if they dont exist
    function getCitizenByUsername(string username) public constant returns(
        bool isExistent,
        address addr,
        uint balance)
    {
        if (!_citizens.isCitizen(username)) {
            return (false, 0x0, 0);
        }

        isExistent = true;
        addr = _citizens.getAddress(username);
        balance = _tokens.balanceOf(addr);

        return;
    }

    // Return all details of citizen with specified address
    // Doesnt throw if they dont exist
    function getCitizenByAddress(address addr) public constant returns(
        bool isExistent,
        string username,
        uint balance)
    {
        if (!_citizens.isCitizen(addr)) {
            return (false, "", 0);
        }

        isExistent = true;
        // Annoyingly cant do username = _citizens.getUsername(addr);
        username = _citizens.citizens[_citizens.idByAddress[addr]].username;
        balance = _tokens.balanceOf(addr);

        return;
    }
    
    function isNumberParameter(bytes32 name) public constant returns(bool) {
        return ParameterLib.isNumberParameter(_storage, name);
    }

    function isStringParameter(bytes32 name) public constant returns(bool) {
        return ParameterLib.isStringParameter(_storage, name);
    }

    function getNumberParameter(bytes32 name) public constant returns(uint current) {
        return ParameterLib.getNumber(_storage, name);
    }

    function getNumberParameterRange(bytes32 name) public constant returns(uint min, uint max) {
        return ParameterLib.getNumberParameterRange(_storage, name);
    }

    function getStringParameter(bytes32 name) public constant returns(bytes32) {
        return ParameterLib.getString(_storage, name);
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
        _tokens.transfer(msg.sender, TokenLib.getPublicAccount(), transactionTax);                
        _tokens.transfer(msg.sender, to, amount);
    }

    function transferFrom(address from, address to, uint value) public returns (bool success) {
        return false; // not supported
    }

    function balanceOf(address owner) constant public returns (uint balance) {
        require(owner == 0x0 || _citizens.isCitizen(owner));
        return _tokens.balanceOf(owner);
    }

    function approve(address spender, uint value) public returns (bool success) {
        return false; // not supported
    }

    function allowance(address owner, address spender) constant public returns (uint remaining) {
        return 0; // not supported
    }

    function name() constant public returns (string) {
        // TODO
        return "VoteCoin";
    }

    function symbol() constant public returns (string) {
        // TODO
        return "VTC";
    }

    function decimals() constant public returns (uint8) {
        return uint8(getNumberParameter(PRM_DECIMALS));
    }

    function totalSupply() constant public returns (uint256) {
        return _tokens.totalSupply;
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
        _referendums[proposalId].init(getNumberParameter(PRM_PROPOSAL_TIME_LIMIT_DAYS) * 1 days);
    }

    function payProposalTax() private {
        uint tax = calculateProposalTax(msg.sender);
        _tokens.transfer(msg.sender, TokenLib.getPublicAccount(), tax);     
    }

    function enactProposal(uint proposalId) private {

        var proposal = _proposals.proposals[proposalId];
        assert(proposal.isExistent);

        if (proposal.typ == ProposalLib.ProposalType.SetParameter) {
                ParameterLib.set(_storage, proposal.stringParam1, proposal.stringParam2, proposal.numberParam1);
            } else if (proposal.typ == ProposalLib.ProposalType.CreateMoney) {
                _tokens.createMoney(proposal.numberParam1);
            } else if (proposal.typ == ProposalLib.ProposalType.DestroyMoney) {
                _tokens.destroyMoney(proposal.numberParam1);        
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

    // Each type fo tax is a token transfer made periodically from each citizen to the public account 
    // The amount transfered for Poll Tax is the value of the parameter 'taxPollTax'
    // If a citizen does not have the required funds then their balance is emptied    
    function applyPollTax() private {
        var pollTaxAmount = getNumberParameter(PRM_POLL_TAX);
        if (pollTaxAmount == 0) {
            return;
        }

        for (_citizens.iterateStart(); _citizens.iterateValid(); _citizens.iterateNext()) {
            var citizen = _citizens.iterateCurrent();
            _tokens.transferAsMuchAsPossibleOf(citizen, TokenLib.getPublicAccount(), pollTaxAmount);
        }
    }

    // Each type fo tax is a token transfer made periodically from each citizen to the public account 
    // The amount transfered for Wealth Tax is the Citizen's balance multiplied by the percentage parameter 'taxWealthTaxPercent'   
    function applyWealthTax() private {

        var wealthTaxPercent = getNumberParameter(PRM_WEALTH_TAX_PERCENT);
        if (wealthTaxPercent == 0) {
            return;
        }

        for (_citizens.iterateStart(); _citizens.iterateValid(); _citizens.iterateNext()) {
            var citizen = _citizens.iterateCurrent();
            var wealthTaxAmount = TaxLib.calculateWealthTax(_tokens.balanceOf(citizen), wealthTaxPercent);
            _tokens.transfer(citizen, TokenLib.getPublicAccount(), wealthTaxAmount); 
        }
    }

    // Basic income is a token transfer made periodically from the Public Account to each Citizen
    // The amount transfered for Basic Income is the value of the parameter 'taxBasicIncome'
    // If the public account does not have enough funds to make all basic income payments then each citizen gets an equal share of the total public funds
    function applyBasicIncome() private {
        var basicIncomeAmount = getNumberParameter(PRM_BASIC_INCOME);
        if (basicIncomeAmount == 0) {
            return;
        }

        var totalValue = basicIncomeAmount.times(_citizens.count);
        var publicFunds = _tokens.balanceOf(TokenLib.getPublicAccount());
        if (totalValue > publicFunds) {
            basicIncomeAmount = publicFunds / _citizens.count;
        }

        for (_citizens.iterateStart(); _citizens.iterateValid(); _citizens.iterateNext()) {
            var citizen = _citizens.iterateCurrent();
            _tokens.transfer(TokenLib.getPublicAccount(), citizen, basicIncomeAmount);  
        }
    }

    // Pay Citizen transfers funds from the Public Account to the specified citizen
    // If the Public Account does not have enough funds then it is emptied into the Citizens account
    function payCitizen(address citizen, uint amount) private {
        assert(_citizens.isCitizen(citizen));
        _tokens.transferAsMuchAsPossibleOf(TokenLib.getPublicAccount(), citizen, amount);
    }

    // Fine Citizen transfers funds from the specified citizen to the Public Account
    // If the Citizen does not have enough funds then thier account is emptied into the Public Account
    function fineCitizen(address citizen, uint amount) private {
        assert(_citizens.isCitizen(citizen));
        _tokens.transferAsMuchAsPossibleOf(citizen, TokenLib.getPublicAccount(), amount);
    }

    modifier onlyCitizen {
        require(_citizens.isCitizen(msg.sender));
        _;
    }

    modifier onlyGatekeeper {
        require(msg.sender == _gatekeeper);
        _;
    }
}