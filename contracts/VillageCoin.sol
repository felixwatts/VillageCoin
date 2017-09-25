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
    ERC20Lib.TokenStorage _balances;
    CitizenLib.Citizenry _citizens;
    ProposalLib.ProposalSet _proposals;
 
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
        
        //addCitizen(PUBLIC_ACCOUNT, "RedditVillage_PublicAccount");
        //_citizenCount = 0; // public account doesnt count towards the citizen count because it does not vote

        _nextTaxTime = now.plus(getNumberParameter("taxPeriodDays").times(1 days)); 
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
        // var isDue = now > _nextTaxTime;
        // if(!isDue) {
        //     return;
        // }

        _nextTaxTime = _nextTaxTime.plus(getNumberParameter("taxPeriodDays").times(1 days)); 

        applyPollTax();
        applyWealthTax();

        applyBasicIncome();
    }

    function tryDecideProposal(uint proposalId) public {
        
        var referendum = _referendums[proposalId];

        var decision = referendum.tryDecide(_citizenCount, _parameters.getNumber("proposalDecideThresholdPercent"));

        if (decision == DemocracyLib.ReferendumDecision.Accepted) {
            enactProposal(proposalId);
        }
    }

    //
    // Citizen actions
    //

    function proposePackage(uint[] partIds, string supportingEvidence) public onlyCitizen {
        payProposalTax(false);
        _proposals.proposePackage(partIds, supportingEvidence);
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
        payProposalTax(isPartOfPackage);
        _proposals.proposeSetParameter(parameterName, stringValue, numberValue, supportingEvidence, isPartOfPackage);        
    }

    function proposeCreateMoney(uint amount, string supportingEvidence, bool isPartOfPackage) public onlyCitizen {
        payProposalTax(isPartOfPackage);
        uint proposalId = _proposals.proposeCreateMoney(amount, supportingEvidence, isPartOfPackage);
        if (!isPartOfPackage) {
            _referendums[proposalId].init();
        }
    }

    function proposeDestroyMoney(uint amount, string supportingEvidence, bool isPartOfPackage) public onlyCitizen {
        payProposalTax(isPartOfPackage);
        _proposals.proposeDestroyMoney(amount, supportingEvidence, isPartOfPackage);
    }

    function proposePayCitizen(address citizen, uint amount, string supportingEvidence, bool isPartOfPackage) public onlyCitizen {
        require(_citizens.isCitizen(citizen));
        payProposalTax(isPartOfPackage);
        _proposals.proposePayCitizen(citizen, amount, supportingEvidence, isPartOfPackage);
    }

    function proposeFineCitizen(address citizen, uint amount, string supportingEvidence, bool isPartOfPackage) public onlyCitizen {
        require(_citizens.isCitizen(citizen));
        payProposalTax(isPartOfPackage);
        _proposals.proposeFineCitizen(citizen, amount, supportingEvidence, isPartOfPackage);        
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

        return TaxLib.calculateProposalTax(proposer, proposalTaxFlat, proposalTaxPercent, balance);
    }

    function calculateTransactionTax(address from, address to, uint amount) public constant returns(uint) {
        uint transactionTaxFlat = _parameters.getNumber("taxTransactionTaxFlat");
        uint transactionTaxPercent = _parameters.getNumber("taxTransactionTaxPercent");
        return TaxLib.calculateTransactionTax(amount, from, to, transactionTaxFlat, transactionTaxPercent);
    }

    function getItemsOfPackage(uint proposalId) public constant returns(uint[]) {
        return _proposals.getItemsOfPackage(proposalId);
    }

    function getAddressOfRedditUsername(string redditUsername) public constant returns(address) {
        return _citizens.getAddress(redditUsername);
    }

    function isRedditUserACitizen(string redditUsername) public constant returns (bool) {

        return _citizens.isCitizen(redditUsername);
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
        string memory result;
        result = _parameters.getString(name);
        return result;
    }

    function isCitizen(address addr) public constant returns (bool) {
        return _citizens.isCitizen(addr);
    }

    function getHasSenderVoted(uint proposalId) returns(bool) {
        return _referendums[proposalId].hasVoted(msg.sender);
    }

    //
    // ERC20
    //

    event Transfer(address indexed from, address indexed to, uint amount);
  
    function transfer(address to, uint value) public onlyCitizen returns (bool success) {
        require(_citizens.isCitizen(to));
        uint transactionTax = calculateTransactionTax(msg.sender, to, amount);
        _balances.transfer(msg.sender, TokenLib.PUBLIC_ACCOUNT, transactionTax);                
        _balances.transfer(msg.sender, to, amount);
    }

    function transferFrom(TokenStorage storage self, address _from, address _to, uint _value) returns (bool success) {
        return false; // not supported
    }

    function balanceOf(address owner) constant returns (uint balance) {
        require(_citizens.isCitizen(owner));
        return _balances.balanceOf(owner);
    }

    function approve(TokenStorage storage self, address _spender, uint _value) returns (bool success) {
        return false; // not supported
    }

    function allowance(TokenStorage storage self, address _owner, address _spender) constant returns (uint remaining) {
        return 0; // not supported
    }

    function name() constant returns (string) {
        return _parameters.getString("name");
    }

    function symbol() constant returns (string) {
        return _parameters.getString("symbol");
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

    function payProposalTax(bool isPartOfPackage) private returns(uint) {

        if (isPartOfPackage) {
            return;
        }

        uint tax = TaxLib.calculateProposalTax(msg.sender, _parameters.getNumber("taxProposalTaxFlat"), _parameters.getNumber("taxProposalTaxPercent"), _balances.balanceOf(msg.sender));
        _balances.transfer(msg.sender, TokenLib.PUBLIC_ACCOUNT, tax);     
    }

    function enactProposal(uint proposalId) private {

        var proposal = _proposals[proposalId];
        assert(proposal.isExistent);

         // to make sure it has not already been enacted

        if (proposal.typ == ProposalType.SetParameter) {
                _parameters.set(proposal.stringParam1, proposal.stringParam2, proposal.numberParam1);
            } else if (proposal.typ == ProposalType.CreateMoney) {
                _balances.createMoney(proposal.numberParam1);
            } else if (proposal.typ == ProposalType.DestroyMoney) {
                _balances.destroyMoney(proposal.numberParam1);        
            } else if (proposal.typ == ProposalType.PayCitizen) {
                payCitizen(proposal.addressParam1, proposal.numberParam1);
            } else if (proposal.typ == ProposalType.FineCitizen) {
                fineCitizen(proposal.addressParam1, proposal.numberParam1);
            } else if (proposal.typ == ProposalType.Package) {
                for (uint i = 0; i < proposal.packageParts.length; i++) {
                    decideProposal(proposal.packageParts[i], decision);
                }
            } else {
                revert();
            }
    }

    // function decideProposal(uint proposalId, ProposalDecision decision) private {        
        
    //     assert(decision != ProposalDecision.Undecided);        

    //     var proposal = _proposals[proposalId];
    //     assert(_proposals[proposalId].isExistent);

    //     var proposalStatus = _proposalStatus[proposalId];                        
    //     assert(proposalStatus.decision == ProposalDecision.Undecided || proposalStatus.decision == ProposalDecision.PackageAssigned);
        
    //     if (!proposal.isPartOfPackage) {
    //         proposalStatus.decision = decision;
    //     }

    //     if (decision == ProposalDecision.Accepted) {
    //         if (proposal.typ == ProposalType.SetParameter) {
    //             setParameter(proposal.stringParam1, proposal.stringParam2, proposal.numberParam1);
    //         } else if (proposal.typ == ProposalType.CreateMoney) {
    //             createMoney(proposal.numberParam1);
    //         } else if (proposal.typ == ProposalType.DestroyMoney) {
    //             destroyMoney(proposal.numberParam1);        
    //         } else if (proposal.typ == ProposalType.PayCitizen) {
    //             payCitizen(proposal.addressParam1, proposal.numberParam1);
    //         } else if (proposal.typ == ProposalType.FineCitizen) {
    //             fineCitizen(proposal.addressParam1, proposal.numberParam1);
    //         } else if (proposal.typ == ProposalType.Package) {
    //             for (uint i = 0; i < proposal.packageParts.length; i++) {
    //                 decideProposal(proposal.packageParts[i], decision);
    //             }
    //         } else {
    //             revert();
    //         }
    //     }

    //     OnProposalDecided(proposalId);
    // }

    function applyPollTax() private {
        var pollTaxAmount = _parameters.getNumber("taxPollTax");
        if (pollTaxAmount == 0) {
            return;
        }

        for (uint i = 0; i < _citizens.allCitizensEver; i++) { 
            address citizen = _citizens.allCitizensEver[i];
            if (_citizens.isCitizen(citizen)) {
                _balances.transferAsMuchAsPossibleOf(citizen, TokenLib.PUBLIC_ACCOUNT, pollTaxAmount);                       
            }
        }
    }

    function applyWealthTax() private {

        var wealthTaxPercent = _parameters.getNumber("taxWealthTaxPercent");
        if (wealthTaxPercent == 0) {
            return;
        }

        for (uint i = 0; i < _citizens.allCitizensEver; i++) { 
            address citizen = _citizens.allCitizensEver[i];
            if (_citizens.isCitizen(citizen)) {
                var wealthTaxAmount = TaxLib.calculateWealthTax(_balances.balanceOf(citizen), wealthTaxPercent);
                _balances.transfer(citizen, TokenLib.PUBLIC_ACCOUNT, wealthTaxAmount);                       
            }
        }
    }

    function applyBasicIncome() private {
        var basicIncomeAmount = _parameters.getNumber("taxBasicIncome");
        if (basicIncomeAmount == 0) {
            return;
        }

        var totalValue = basicIncomeAmount.times(_citizenCount);
        var publicFunds = _balances.balanceOf(PUBLIC_ACCOUNT);
        if (totalValue > publicFunds) {
            basicIncomeAmount = publicFunds / _citizens.count;
        }

        for (uint i = 0; i < _citizens.allCitizensEver.length; i++) {
            address citizen = _citizens.allCitizensEver[i];

            if (_citizens[citizen].isExistent) { 
                _balances.transfer(PUBLIC_ACCOUNT, citizen, basicIncomeAmount);                            
            }
        }
    }

    function payCitizen(address citizen, uint amount) private {
        assert(isCitizen(citizen));
        _balances.transferAsMuchAsPossibleOf(TokenLib.PUBLIC_ACCOUNT, citizen, amount);
    }

    function fineCitizen(address citizen, uint amount) private {
        assert(isCitizen(citizen));
        _balances.transferAsMuchAsPossibleOf(citizen, TokenLib.PUBLIC_ACCOUNT, amount);
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