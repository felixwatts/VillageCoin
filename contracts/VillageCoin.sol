pragma solidity ^0.4.9;

import "./SafeMath.sol";
import "./Receiver_Interface.sol";
import "./ERC223_Interface.sol";

contract VillageCoin is ERC223, SafeMath {

    address public _gatekeeper;

    address PUBLIC_ACCOUNT = 0; 

    struct Parameter {
        uint numberValue;
        string stringValue;
        bool isNumber;
        bool isExistent;
        uint minNumberValue;
        uint maxNumberValue; // 0 = no max
    }

    mapping(string=>Parameter) _parameters;
    
    struct Citizen {        
        address owner;
        uint balance;
        bool isExistent;
        string redditUsername;
    }  

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

    mapping(uint=>mapping(address=>bool)) _votes;

    struct Proposal {
        uint id;        
        ProposalType typ;
        uint voteCountYes;
        uint voteCountNo;
        address proposer;        
        bool isExistent;
        ProposalDecision decision;
        uint expiryTime;

        string setParameterParameterName;
        string setParameterParameterStringValue;
        uint setParameterParameterNumberValue;

        uint createMoneyAmount;

        uint destroyMoneyAmount;

        address payCitizenCitizen;
        uint payCitizenAmount;

        address fineCitizenCitizen;
        uint fineCitizenAmount;

        string supportingEvidence;
    }  

    event OnProposalCreated(uint proposalId);
    event OnProposalDecided(uint proposalId);

    uint256 public _totalSupply;

    mapping(address=>Citizen) public _citizens;
    uint public _citizenCount;
    address[] public _allCitizenOwnersEver;

    uint public _nextProposalId;
    mapping(uint=>Proposal) _proposals;   

    uint _nextTaxTime; 

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
    // Management Methods
    //

    function addCitizen(address addr, string redditUsername) onlyGatekeeper public {
        require(!isRedditUserACitizen(redditUsername));

        _citizens[addr].owner = addr;
        _citizens[addr].isExistent = true;
        _citizens[addr].balance = getNumberParameter("initialAccountBalance");
        _citizens[addr].redditUsername = redditUsername;

        _totalSupply = safeAdd(_totalSupply, _citizens[addr].balance);   
        _citizenCount++;
        _allCitizenOwnersEver.push(addr); // todo what if citizen is removed and re-added?
    }

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

    function proposeSetParameter (
        string parameterName,
        string stringValue,
        uint numberValue,
        string supportingEvidence
    ) public onlyCitizen 
    {
        require(_parameters[parameterName].isExistent);

        var proposalId = createProposal(ProposalType.SetParameter, supportingEvidence);

        _proposals[proposalId].setParameterParameterName = parameterName;

        if (isNumberParameter(parameterName)) {
            _proposals[proposalId].setParameterParameterNumberValue = numberValue;
        } else if (isStringParameter(parameterName)) {
            require(numberValue == 0);
            _proposals[proposalId].setParameterParameterStringValue = stringValue;
        } else {
            assert(false);
        }

        OnProposalCreated(proposalId);
    }

    function proposeCreateMoney(uint amount, string supportingEvidence) public onlyCitizen {

        var proposalId = createProposal(ProposalType.CreateMoney, supportingEvidence);

        _proposals[proposalId].createMoneyAmount = amount;

        OnProposalCreated(proposalId);
    }

    function proposeDestroyMoney(uint amount, string supportingEvidence) public onlyCitizen {

        var proposalId = createProposal(ProposalType.DestroyMoney, supportingEvidence);

        _proposals[proposalId].destroyMoneyAmount = amount;

        OnProposalCreated(proposalId);
    }

    function proposePayCitizen(address citizen, uint amount, string supportingEvidence) public onlyCitizen {
        require(isCitizen(citizen));

        var proposalId = createProposal(ProposalType.PayCitizen, supportingEvidence);
        _proposals[proposalId].payCitizenCitizen = citizen;
        _proposals[proposalId].payCitizenAmount = amount;

        OnProposalCreated(proposalId);
    }

    // function proposeTaxWealth(uint percent) public onlyCitizen {
    //     var proposalId = _nextProposalId++;
    //     assert(!_proposals[proposalId].isExistent);

    //     _proposals[proposalId].isExistent = true;
    //     _proposals[proposalId].expiryTime = now + _parameters.proposalTimeLimit;
    //     _proposals[proposalId].typ = ProposalType.TaxWealth;
    //     _proposals[proposalId].taxWealthPercent = percent;

    //     OnProposalCreated(proposalId);
    // }

    // function proposeSpendPublicMoney(address to, uint amount) public onlyCitizen {
    //     var proposalId = _nextProposalId++;
    //     assert(!_proposals[proposalId].isExistent);

    //     _proposals[proposalId].isExistent = true;
    //     _proposals[proposalId].expiryTime = now + _parameters.proposalTimeLimit;
    //     _proposals[proposalId].typ = ProposalType.SpendPublicMoney;
    //     _proposals[proposalId].spendPublicMoneyTo = to;
    //     _proposals[proposalId].spendPublicMoneyAmount = amount;

    //     OnProposalCreated(proposalId);
    // }

    function isRedditUserACitizen(string redditUsername) public constant returns (bool) {

        for (uint i = 0; i < _allCitizenOwnersEver.length; i++) {
            var accountOwner = _allCitizenOwnersEver[i];
            var citizen = _citizens[accountOwner];

            if (citizen.isExistent && (sha3(citizen.redditUsername) == sha3(redditUsername))) {
                return true;
            }
        }

        return false;
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
    // Views
    //

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

    function getVillageDetails() public constant returns(string, uint) {
        return (getStringParameter("name"), _citizenCount);
    }

    function getCitizenCount() public constant returns(uint) {
        return _citizenCount;
    }

    function getProposalDecideThresholdPercent() public constant returns(uint) {
        return getNumberParameter("proposalDecideThresholdPercent");
    }

    function isCitizen(address addr) public constant returns (bool) {
        return _citizens[addr].isExistent;
    }

    function getMaxProposalId() public constant returns (uint) {
        return _nextProposalId;
    }

    function getProposalBasicDetails(uint proposalId) public constant returns (uint id, bool isExistent, ProposalDecision decision, bool hasSenderVoted, ProposalType typ, uint expiryTime, string supportingEvidence) {
        return (proposalId, _proposals[proposalId].isExistent, _proposals[proposalId].decision, _votes[proposalId][msg.sender], _proposals[proposalId].typ, _proposals[proposalId].expiryTime, _proposals[proposalId].supportingEvidence);
    }

    function getProposalVotes(uint proposalId) public constant returns (uint id, uint voteCountYes, uint voteCountNo) {
        return (proposalId, _proposals[proposalId].voteCountYes, _proposals[proposalId].voteCountNo);
    }

    function getSetParameterProposal(uint proposalId) public constant returns(uint id, string name, string stringValue, uint numberValue) {
        var proposal = _proposals[proposalId];
        return (proposalId, proposal.setParameterParameterName, proposal.setParameterParameterStringValue, proposal.setParameterParameterNumberValue);
    }

    function getCreateMoneyProposal(uint proposalId) public constant returns(uint id, uint amount) {
        var proposal = _proposals[proposalId];
        return (proposalId, proposal.createMoneyAmount);
    }

    function getDestroyMoneyProposal(uint proposalId) public constant returns(uint id, uint amount) {
        var proposal = _proposals[proposalId];
        return (proposalId, proposal.destroyMoneyAmount);
    }

    function getPayCitizenProposal(uint proposalId) public constant returns(uint id, address citizen, uint amount) {
        var proposal = _proposals[proposalId];
        return (proposalId, proposal.payCitizenCitizen, proposal.payCitizenAmount);
    }

    function getFineCitizenProposal(uint proposalId) public constant returns(uint id, address citizen, uint amount) {
        var proposal = _proposals[proposalId];
        return (proposalId, proposal.fineCitizenCitizen, proposal.fineCitizenAmount);
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

    function createProposal(ProposalType typ, string supportingEvidence) private returns(uint) {
        var proposalId = _nextProposalId++;
        assert(!_proposals[proposalId].isExistent);

        _proposals[proposalId].isExistent = true;
        _proposals[proposalId].typ = typ;
        _proposals[proposalId].expiryTime = now + getNumberParameter("proposalTimeLimitDays") * 1 days;
        _proposals[proposalId].supportingEvidence = supportingEvidence;

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
                setParameter(proposal.setParameterParameterName, proposal.setParameterParameterStringValue, proposal.setParameterParameterNumberValue);
            } else if (proposal.typ == ProposalType.CreateMoney) {
                createMoney(proposal.createMoneyAmount);
            } else if (proposal.typ == ProposalType.DestroyMoney) {
                destroyMoney(proposal.destroyMoneyAmount);        
            } else if (proposal.typ == ProposalType.PayCitizen) {
                payCitizen(proposal.payCitizenCitizen, proposal.payCitizenAmount);
            // } else if (proposal.typ == ProposalType.TaxWealth) {
            //     taxWealth(proposal.taxWealthPercent);
            // } else if (proposal.typ == ProposalType.SpendPublicMoney) {
            //     spendPublicMoney(proposal.spendPublicMoneyTo, proposal.spendPublicMoneyAmount);
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

        if(amount > _citizens[PUBLIC_ACCOUNT].balance) {
            amount = _citizens[PUBLIC_ACCOUNT].balance;
        }

        transferInternal(PUBLIC_ACCOUNT, citizen, amount);
    }

    function fineCitizen(address citizen, uint amount) private {
        assert(isCitizen(citizen));

        if(amount > _citizens[citizen].balance) {
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