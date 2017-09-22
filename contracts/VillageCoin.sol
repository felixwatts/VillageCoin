pragma solidity ^0.4.9;

import "./SafeMath.sol";
import "./Receiver_Interface.sol";
import "./ERC223_Interface.sol";

contract VillageCoin is ERC223, SafeMath {

    //
    // Constants
    //
    
    address PUBLIC_ACCOUNT = 0; 

    //
    // Structs
    //

    struct Parameter {
        uint numberValue;
        string stringValue;
        bool isNumber;
        bool isExistent;
        uint minNumberValue;
        uint maxNumberValue; // 0 = no max
    }
    
    struct Citizen {        
        address owner;
        uint balance;
        bool isExistent;
        string redditUsername;
    }  

    struct Proposal {
        ProposalType typ;
        uint voteCountYes;
        uint voteCountNo;
        address proposer;        
        bool isExistent;
        ProposalDecision decision;
        uint expiryTime;
        string stringParam1;
        string stringParam2;        
        uint numberParam1;                
        address addressParam1;                    
        string supportingEvidenceUrl;
    }

    //
    // Enums
    //

    enum ProposalType { 
        SetParameter, 
        CreateMoney, 
        DestroyMoney,
        PayCitizen, 
        FineCitizen 
        }

    enum ProposalDecision {
        Undecided,
        Accepted,
        Rejected,
        Expired
    }

    //
    // Fields
    //

    address public _gatekeeper;
    uint256 public _totalSupply;
    uint public _nextTaxTime;
    string public _announcementMessage; 

    mapping(string=>Parameter) _parameters;

    mapping(address=>Citizen) public _citizens;
    mapping(string=>address) _citizenByRedditUsername;
    uint public _citizenCount;
    address[] public _allCitizenOwnersEver;

    uint public _nextProposalId;
    mapping(uint=>Proposal) public _proposals;  
    mapping(uint=>mapping(address=>bool)) _votes; 

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
        
        _parameters["name"] = Parameter({stringValue:"RedditVillage", numberValue:0, isNumber:false, isExistent:true, minNumberValue:0, maxNumberValue:0});
        _parameters["symbol"] = Parameter({stringValue:"RVX", numberValue:0, isNumber:false, isExistent:true, minNumberValue:0, maxNumberValue:0});
        _parameters["decimals"] = Parameter({stringValue:"", numberValue:0, isNumber:true, isExistent:true, minNumberValue:0, maxNumberValue:8});

        _parameters["initialAccountBalance"] = Parameter({stringValue:"", numberValue:1000, isNumber:true, isExistent:true, minNumberValue:0, maxNumberValue:0});
        _parameters["proposalDecideThresholdPercent"] = Parameter({stringValue:"", numberValue:1, isNumber:true, isExistent:true, minNumberValue:0, maxNumberValue:100});
        _parameters["proposalTimeLimitDays"] = Parameter({stringValue:"", numberValue:30, isNumber:true, isExistent:true, minNumberValue:0, maxNumberValue:365});

        _parameters["citizenRequirementMinCommentKarma"] = Parameter({stringValue:"", numberValue:500, isNumber:true, isExistent:true, minNumberValue:100, maxNumberValue:0});
        _parameters["citizenRequirementMinPostKarma"] = Parameter({stringValue:"", numberValue:0, isNumber:true, isExistent:true, minNumberValue:0, maxNumberValue:0});

        _parameters["taxPeriodDays"] = Parameter({stringValue:"", numberValue:7, isNumber:true, isExistent:true, minNumberValue:1, maxNumberValue:0});
        _parameters["taxPollTax"] = Parameter({stringValue:"", numberValue:1, isNumber:true, isExistent:true, minNumberValue:0, maxNumberValue:0});
        _parameters["taxWealthTaxPercent"] = Parameter({stringValue:"", numberValue:0, isNumber:true, isExistent:true, minNumberValue:0, maxNumberValue:100});
        _parameters["taxBasicIncome"] = Parameter({stringValue:"", numberValue:0, isNumber:true, isExistent:true, minNumberValue:0, maxNumberValue:0});        
        
        addCitizen(PUBLIC_ACCOUNT, "RedditVillage_PublicAccount");
        _citizenCount = 0; // public account doesnt count towards the citizen count because it does not vote

        _nextTaxTime = now + getNumberParameter("taxPeriodDays") * 1 days; 
    }

    //
    // Gatekeeper actions
    //

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
        require(!isRedditUserACitizen(redditUsername));

        _citizens[addr].owner = addr;
        _citizens[addr].isExistent = true;
        _citizens[addr].balance = getNumberParameter("initialAccountBalance");
        _citizens[addr].redditUsername = redditUsername;

        _citizenByRedditUsername[redditUsername] = addr;

        _totalSupply = safeAdd(_totalSupply, _citizens[addr].balance);   
        _citizenCount++;
        _allCitizenOwnersEver.push(addr); // todo what if citizen is removed and re-added?
    }

    //
    // Public actions
    //

    function applyTaxesIfDue() public {
        // var isDue = now > _nextTaxTime;
        // if(!isDue) {
        //     return;
        // }

        _nextTaxTime += getNumberParameter("taxPeriodDays") * 1 days; 

        applyPollTax();
        applyWealthTax();

        applyBasicIncome();
    }

    function tryDecideProposal(uint proposalId) public {

        assert(_proposals[proposalId].isExistent);
        assert(_proposals[proposalId].decision == ProposalDecision.Undecided);

        var proposal = _proposals[proposalId];

        var percentYes = ((proposal.voteCountYes * 100) / _citizenCount);
        var percentNo = ((proposal.voteCountNo * 100) / _citizenCount);

        var threshold = getNumberParameter("proposalDecideThresholdPercent");

        if (percentYes >= threshold) {
            decideProposal(proposalId, ProposalDecision.Accepted);
        } else if (percentNo >= threshold) {
            decideProposal(proposalId, ProposalDecision.Rejected);
        } else if (now > proposal.expiryTime) {
            decideProposal(proposalId, ProposalDecision.Expired);
        }
    }

    //
    // Citizen actions
    //

    function proposeSetParameter (
        string parameterName,
        string stringValue,
        uint numberValue,
        string supportingEvidence
    ) public onlyCitizen 
    {
        require(_parameters[parameterName].isExistent);

        createProposal(ProposalType.SetParameter, supportingEvidence, parameterName, stringValue, numberValue, 0x0);
    }

    function proposeCreateMoney(uint amount, string supportingEvidence) public onlyCitizen {

        createProposal(ProposalType.CreateMoney, supportingEvidence, "", "", amount, 0x0);
    }

    function proposeDestroyMoney(uint amount, string supportingEvidence) public onlyCitizen {

        createProposal(ProposalType.DestroyMoney, supportingEvidence, "", "", amount, 0x0);
    }

    function proposePayCitizen(address citizen, uint amount, string supportingEvidence) public onlyCitizen {
        require(isCitizen(citizen));

        createProposal(ProposalType.PayCitizen, supportingEvidence, "", "", amount, citizen);
    }

    function proposeFineCitizen(address citizen, uint amount, string supportingEvidence) public onlyCitizen {
        require(isCitizen(citizen));

        createProposal(ProposalType.FineCitizen, supportingEvidence, "", "", amount, citizen);
    }

    function voteOnProposal(uint proposalId, bool isYes) public onlyCitizen {
        require(_proposals[proposalId].isExistent);
        require(_proposals[proposalId].decision == ProposalDecision.Undecided);
        require(!_votes[proposalId][msg.sender]);

        _votes[proposalId][msg.sender] = true;          
        if (isYes) {
            _proposals[proposalId].voteCountYes++;
        } else {
            _proposals[proposalId].voteCountNo++;
        }
    }

    //
    // Views
    //

    function getAddressOfRedditUsername(string redditUsername) public constant returns(address) {
        return _citizenByRedditUsername[redditUsername];
    }

    function isRedditUserACitizen(string redditUsername) public constant returns (bool) {

        return _citizenByRedditUsername[redditUsername] != 0;
    }

    function isNumberParameter(string name) public constant returns(bool) {
        return _parameters[name].isExistent && _parameters[name].isNumber;
    }

    function isStringParameter(string name) public constant returns(bool) {
        return _parameters[name].isExistent && !_parameters[name].isNumber;
    }

    function getNumberParameter(string name) public constant returns(uint current) {
        require(_parameters[name].isExistent);
        require(_parameters[name].isNumber);
        return _parameters[name].numberValue;
    }
    
    function getNumberParameterRange(string name) public constant returns(uint min, uint max) {
        require(_parameters[name].isExistent);
        require(_parameters[name].isNumber);
        return (_parameters[name].minNumberValue, _parameters[name].maxNumberValue);
    }

    function getStringParameter(string name) public constant returns(string) {
        require(_parameters[name].isExistent);
        require(!_parameters[name].isNumber);
        return _parameters[name].stringValue;
    }

    function getProposalDecideThresholdPercent() public constant returns(uint) {
        return getNumberParameter("proposalDecideThresholdPercent");
    }

    function isCitizen(address addr) public constant returns (bool) {
        return _citizens[addr].isExistent;
    }

    function getHasSenderVoted(uint proposalId) returns(bool) {
        return _votes[proposalId][msg.sender];
    }
   
    //
    // ERC223
    //

    function name() constant returns (string) {
        return getStringParameter("name");
    }

    function symbol() constant returns (string) {
        return getStringParameter("symbol");
    }

    function decimals() constant returns (uint8) {
        return uint8(getNumberParameter("decimals"));
    }

    function totalSupply() constant returns (uint256) {
        return _totalSupply;
    }
  
    // Function that is called when a user or another contract wants to transfer funds .
    function transfer(address to, uint value, bytes data, string customFallback) public onlyCitizen returns (bool success) {
        
        if (isContract(to)) {
            transferInternal(msg.sender, to, value, data);
            ContractReceiver receiver = ContractReceiver(to);
            receiver.call.value(0)(bytes4(sha3(customFallback)), msg.sender, value, data);
            Transfer(msg.sender, to, value, data);
            return true;
        } else {
            transferInternal(msg.sender, to, value, data);
            return true;
        }
    }
  
    // Function that is called when a user or another contract wants to transfer funds .
    function transfer(address to, uint value, bytes data) public onlyCitizen returns (bool success) {
        
        if (isContract(to)) {
            return transferToContract(to, value, data);
        } else {
            return transferToAddress(to, value, data);
        }
    }
  
    // Standard function transfer similar to ERC20 transfer with no _data .
    // Added due to backwards compatibility reasons .
    function transfer(address to, uint value) public onlyCitizen returns (bool success) {
        
        //standard function transfer similar to ERC20 transfer with no _data
        //added due to backwards compatibility reasons
        bytes memory empty;
        if (isContract(to)) {
            return transferToContract(to, value, empty);
        } else {
            return transferToAddress(to, value, empty);
        }
    }

    //assemble the given address bytecode. If bytecode exists then the _addr is a contract.
    function isContract(address addr) private returns (bool) {
        uint length;
        assembly {
                //retrieve the size of the code on target address, this needs assembly
                length := extcodesize(addr)
        }
        return (length>0);
    }

    //function that is called when transaction target is an address
    function transferToAddress(address to, uint value, bytes data) private onlyCitizen returns (bool success) {
        transferInternal(msg.sender, to, value, data);
        return true;
    }
  
    //function that is called when transaction target is a contract
    function transferToContract(address to, uint value, bytes data) private onlyCitizen returns (bool success) {
        transferInternal(msg.sender, to, value, data);
        ContractReceiver receiver = ContractReceiver(to);
        receiver.tokenFallback(msg.sender, value, data);
        return true;
    }

    function balanceOf(address addr) public constant returns (uint balance) {
        require(isCitizen(addr));
        return _citizens[addr].balance;
    }

    //
    // Internal Stuff
    //

    function createProposal(ProposalType typ, string supportingEvidenceUrl, string stringParam1, string stringParam2, uint numberParam1, address addressParam1) private returns(uint) {
        var proposalId = _nextProposalId++;
        assert(!_proposals[proposalId].isExistent);

        _proposals[proposalId].isExistent = true;
        _proposals[proposalId].typ = typ;
        _proposals[proposalId].expiryTime = now + getNumberParameter("proposalTimeLimitDays") * 1 days;
        _proposals[proposalId].supportingEvidenceUrl = supportingEvidenceUrl;
        _proposals[proposalId].stringParam1 = stringParam1;
        _proposals[proposalId].stringParam2 = stringParam2;
        _proposals[proposalId].numberParam1 = numberParam1;
        _proposals[proposalId].addressParam1 = addressParam1;

        OnProposalCreated(proposalId);

        return proposalId;
    }

    function decideProposal(uint proposalId, ProposalDecision decision) private {        
        
        assert(decision != ProposalDecision.Undecided);

        var proposal = _proposals[proposalId];
                
        assert(proposal.isExistent);
        assert(proposal.decision == ProposalDecision.Undecided);
        
        proposal.decision = decision;

        if (decision == ProposalDecision.Accepted) {
            if (proposal.typ == ProposalType.SetParameter) {
                setParameter(proposal.stringParam1, proposal.stringParam2, proposal.numberParam1);
            } else if (proposal.typ == ProposalType.CreateMoney) {
                createMoney(proposal.numberParam1);
            } else if (proposal.typ == ProposalType.DestroyMoney) {
                destroyMoney(proposal.numberParam1);        
            } else if (proposal.typ == ProposalType.PayCitizen) {
                payCitizen(proposal.addressParam1, proposal.numberParam1);
            } else if (proposal.typ == ProposalType.FineCitizen) {
                fineCitizen(proposal.addressParam1, proposal.numberParam1);
            } else {
                revert();
            }
        }

        OnProposalDecided(proposalId);
    }

    function setParameter(string parameterName, string stringValue, uint numberValue) private {
        assert(_parameters[parameterName].isExistent);

        if (isNumberParameter(parameterName)) {

            require(numberValue >= _parameters[parameterName].minNumberValue);
            if (_parameters[parameterName].maxNumberValue != 0) {
                require(numberValue <= _parameters[parameterName].maxNumberValue);
            }

            _parameters[parameterName].numberValue = numberValue;
        } else if (isStringParameter(parameterName)) {
            assert(numberValue == 0);
            _parameters[parameterName].stringValue = stringValue;
        } else {
            revert();
        }
    }

    function applyPollTax() private {
        var pollTaxAmount = getNumberParameter("taxPollTax");
        if (pollTaxAmount == 0) {
            return;
        }

        for (uint i = 0; i < _allCitizenOwnersEver.length; i++) { // starts at 1 to skip public account
            var accountOwner = _allCitizenOwnersEver[i];

            if (_citizens[accountOwner].isExistent) {

                var amountToTransfer = _citizens[accountOwner].balance >= pollTaxAmount
                    ? pollTaxAmount
                    : _citizens[accountOwner].balance;

                transferInternal(accountOwner, PUBLIC_ACCOUNT, amountToTransfer);                        
            }
        }
    }

    function applyWealthTax() private {

        var wealthTaxPercent = getNumberParameter("taxWealthTaxPercent");
        if (wealthTaxPercent == 0) {
            return;
        }

        for (uint i = 0; i < _allCitizenOwnersEver.length; i++) { // starts at 1 to skip public account
            var accountOwner = _allCitizenOwnersEver[i];

            if (_citizens[accountOwner].isExistent) {
                var amountToTax = (wealthTaxPercent * _citizens[accountOwner].balance) / 100;
                transferInternal(accountOwner, PUBLIC_ACCOUNT, amountToTax);
            }
        }
    }

    function applyBasicIncome() private {
        var basicIncomeAmount = getNumberParameter("taxBasicIncome");
        if (basicIncomeAmount == 0) {
            return;
        }

        var totalValue = safeMul(basicIncomeAmount, _citizenCount);
        var publicFunds = balanceOf(PUBLIC_ACCOUNT);
        if (totalValue > publicFunds) {
            basicIncomeAmount = publicFunds / _citizenCount;
        }

        for (uint i = 1; i < _allCitizenOwnersEver.length; i++) { // starts at 1 to skip public account
            var accountOwner = _allCitizenOwnersEver[i];

            if (_citizens[accountOwner].isExistent) {                
                transferInternal(PUBLIC_ACCOUNT, accountOwner, basicIncomeAmount);
            }
        }
    }

    function createMoney(uint amount) private {

        _citizens[PUBLIC_ACCOUNT].balance = safeAdd(_citizens[PUBLIC_ACCOUNT].balance, amount);
        _totalSupply = safeAdd(_totalSupply, amount);
        
        bytes memory empty;
        Transfer(PUBLIC_ACCOUNT, PUBLIC_ACCOUNT, amount, empty);
    }

    function destroyMoney(uint amount) private {

        if (amount > _citizens[PUBLIC_ACCOUNT].balance) {
            amount = _citizens[PUBLIC_ACCOUNT].balance;
        }

        _citizens[PUBLIC_ACCOUNT].balance -= amount;
        _totalSupply -= amount;
        
        bytes memory empty;
        Transfer(PUBLIC_ACCOUNT, PUBLIC_ACCOUNT, amount, empty);
    }

    function payCitizen(address citizen, uint amount) private {
        assert(isCitizen(citizen));

        if (amount > _citizens[PUBLIC_ACCOUNT].balance) {
            amount = _citizens[PUBLIC_ACCOUNT].balance;
        }

        transferInternal(PUBLIC_ACCOUNT, citizen, amount);
    }

    function fineCitizen(address citizen, uint amount) private {
        assert(isCitizen(citizen));

        if (amount > _citizens[citizen].balance) {
            amount = _citizens[citizen].balance;
        }

        transferInternal(citizen, PUBLIC_ACCOUNT, amount);
    }

    function transferInternal(address from, address to, uint amount) private {
        bytes memory empty;
        transferInternal(from, to, amount, empty);
    }

    function transferInternal(address from, address to, uint amount, bytes data) private {
        assert(isCitizen(from));        
        assert(isCitizen(to));
        assert(_citizens[from].balance >= amount);

        _citizens[from].balance -= amount;
        _citizens[to].balance = safeAdd(_citizens[to].balance, amount);

        Transfer(from, to, amount, data);
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