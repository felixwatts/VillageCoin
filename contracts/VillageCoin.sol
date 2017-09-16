pragma solidity ^0.4.9;

import "./SafeMath.sol";
import "./Receiver_Interface.sol";
import "./ERC223_Interface.sol";

contract VillageCoin is ERC223, SafeMath {

    event Debug(string message);

    address PUBLIC_ACCOUNT = 0; 

    struct ContractParameters {
        uint initialAccountBalance;
        uint proposalDecideThresholdPercent;
        uint proposalTimeLimit;
        string accessPolicyDescription;
        string accessEvidenceRequirementsDescription;
    }
    
    struct Citizen {        
        address owner;
        uint balance;
        bool isGatekeeper;
        bool isExistent;
    }  

    enum ProposalType { 
        AppointGatekeeper, 
        DismissGatekeeper, 
        AddCitizen, 
        RemoveCitizen, 
        SetContractParameters, 
        CreateMoney, 
        TaxWealth, 
        SpendPublicMoney 
        }

    enum ProposalDecision {
        Undecided,
        Accepted,
        Rejected,
        Expired
    }

    struct Proposal {
        uint id;        
        ProposalType typ;
        uint voteCountYes;
        uint voteCountNo;
        mapping(address=>bool) hasVoted;
        bool isExistent;
        ProposalDecision decision;
        uint expiryTime;

        address appointGatekeeperId;

        address dismissGatekeeperId;

        address addCitizenId;        

        address removeCitizenId;

        ContractParameters setContractParametersParameters;

        uint createMoneyAmountPerAccount;

        uint taxWealthPercent;

        address spendPublicMoneyTo;
        uint spendPublicMoneyAmount;

        string supportingEvidenceSwarmAddress;
    }  

    event OnProposalCreated(uint proposalId);
    event OnProposalDecided(uint proposalId);

    string public _name;
    string public _symbol;
    uint8 public _decimals;
    uint256 public _totalSupply;

    ContractParameters _parameters;

    mapping(address=>Citizen) _citizens;
    uint _citizenCount;
    uint _gatekeeperCount;
    address[] _allCitizenOwnersEver;

    uint _nextProposalId;
    mapping(uint=>Proposal) _proposals;    

    function VillageCoin(string name, string symbol, uint8 decimals, address firstCitizen) payable {
        _name = name;
        _symbol = symbol;
        _decimals = decimals;
        _parameters.initialAccountBalance = 1000;
        _parameters.proposalDecideThresholdPercent = 60;
        _parameters.proposalTimeLimit = 30 days;
        _parameters.accessPolicyDescription = "open to anyone";
        _parameters.accessEvidenceRequirementsDescription = "";
        
        addCitizen(PUBLIC_ACCOUNT);
        _citizenCount = 0; // public account doesnt count towards the citizen count because it does not vote
        addCitizen(firstCitizen);
        appointGatekeeper(firstCitizen);
    }

    //
    // Management Methods
    //

    function proposeAppointGatekeeper(address id) public onlyCitizen {
        require(!isGatekeeper(id));

        var proposalId = _nextProposalId++;
        assert(!_proposals[proposalId].isExistent);

        _proposals[proposalId].isExistent = true;
        _proposals[proposalId].expiryTime = now + _parameters.proposalTimeLimit;
        _proposals[proposalId].typ = ProposalType.AppointGatekeeper;
        _proposals[proposalId].appointGatekeeperId = id;

        OnProposalCreated(proposalId);
    }

    function proposeDismissGatekeeper(address id) public onlyCitizen {
        require(isGatekeeper(id));

        var proposalId = _nextProposalId++;
        assert(!_proposals[proposalId].isExistent);

        _proposals[proposalId].isExistent = true;
        _proposals[proposalId].expiryTime = now + _parameters.proposalTimeLimit;
        _proposals[proposalId].typ = ProposalType.DismissGatekeeper;
        _proposals[proposalId].dismissGatekeeperId = id;

        OnProposalCreated(proposalId);
    }

    function proposeAddCitizen(address id, string supportingEvidenceSwarmAddress) public {
        require(!isCitizen(id));

        var proposalId = _nextProposalId++;
        assert(!_proposals[proposalId].isExistent);

        _proposals[proposalId].isExistent = true;
        _proposals[proposalId].expiryTime = now + _parameters.proposalTimeLimit;
        _proposals[proposalId].typ = ProposalType.AddCitizen;
        _proposals[proposalId].addCitizenId = id;
        _proposals[proposalId].supportingEvidenceSwarmAddress = supportingEvidenceSwarmAddress;

        OnProposalCreated(proposalId);
    }

    function proposeRemoveCitizen(address id) public onlyCitizen {
        require(isCitizen(id));

        var proposalId = _nextProposalId++;
        assert(!_proposals[proposalId].isExistent);

        _proposals[proposalId].isExistent = true;
        _proposals[proposalId].expiryTime = now + _parameters.proposalTimeLimit;
        _proposals[proposalId].typ = ProposalType.RemoveCitizen;
        _proposals[proposalId].removeCitizenId = id;

        OnProposalCreated(proposalId);
    }

    function proposeSetContractParameters (
        uint initialAccountBalance,
        uint proposalDecideThresholdPercent,
        uint proposalTimeLimitDays) public onlyCitizen 
    {
        var proposalId = _nextProposalId++;
        assert(!_proposals[proposalId].isExistent);

        _proposals[proposalId].isExistent = true;
        _proposals[proposalId].expiryTime = now + _parameters.proposalTimeLimit;
        _proposals[proposalId].typ = ProposalType.SetContractParameters;
        _proposals[proposalId].setContractParametersParameters.initialAccountBalance = initialAccountBalance;
        _proposals[proposalId].setContractParametersParameters.proposalDecideThresholdPercent = proposalDecideThresholdPercent;
        _proposals[proposalId].setContractParametersParameters.proposalTimeLimit = proposalTimeLimitDays * 1 days;

        OnProposalCreated(proposalId);
    }

    function proposeCreateMoney(uint amountPerAccount) public onlyCitizen {
        var proposalId = _nextProposalId++;
        assert(!_proposals[proposalId].isExistent);

        _proposals[proposalId].isExistent = true;
        _proposals[proposalId].expiryTime = now + _parameters.proposalTimeLimit;
        _proposals[proposalId].typ = ProposalType.CreateMoney;
        _proposals[proposalId].createMoneyAmountPerAccount = amountPerAccount;

        OnProposalCreated(proposalId);
    }

    function proposeTaxWealth(uint percent) public onlyCitizen {
        var proposalId = _nextProposalId++;
        assert(!_proposals[proposalId].isExistent);

        _proposals[proposalId].isExistent = true;
        _proposals[proposalId].expiryTime = now + _parameters.proposalTimeLimit;
        _proposals[proposalId].typ = ProposalType.TaxWealth;
        _proposals[proposalId].taxWealthPercent = percent;

        OnProposalCreated(proposalId);
    }

    function proposeSpendPublicMoney(address to, uint amount) public onlyCitizen {
        var proposalId = _nextProposalId++;
        assert(!_proposals[proposalId].isExistent);

        _proposals[proposalId].isExistent = true;
        _proposals[proposalId].expiryTime = now + _parameters.proposalTimeLimit;
        _proposals[proposalId].typ = ProposalType.SpendPublicMoney;
        _proposals[proposalId].spendPublicMoneyTo = to;
        _proposals[proposalId].spendPublicMoneyAmount = amount;

        OnProposalCreated(proposalId);
    }

    function voteOnProposal(uint proposalId, bool isYes) public onlyCitizen {
        require(_proposals[proposalId].isExistent);
        require(_proposals[proposalId].decision == ProposalDecision.Undecided);
        require(!_proposals[proposalId].hasVoted[msg.sender]);
        
        if (_proposals[proposalId].typ == ProposalType.AddCitizen) {
            require(isGatekeeper(msg.sender));
        }

        _proposals[proposalId].hasVoted[msg.sender] = true;        
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

        var totalVoters = (proposal.typ == ProposalType.AddCitizen) ? _gatekeeperCount : _citizenCount;

        var percentYes = ((proposal.voteCountYes * 100) / totalVoters);
        var percentNo = ((proposal.voteCountNo * 100) / totalVoters);

        if (percentYes >= _parameters.proposalDecideThresholdPercent) {
            decideProposal(proposalId, ProposalDecision.Accepted);
        } else if (percentNo >= _parameters.proposalDecideThresholdPercent) {
            decideProposal(proposalId, ProposalDecision.Rejected);
        } else if (now > proposal.expiryTime) {
            decideProposal(proposalId, ProposalDecision.Expired);
        }
    }

    //
    // Views
    //

    function getVillageDetails() public constant returns (string, string, uint) {
        return ("A", "B", 1);
    }

    function getCitizenCount() public constant returns(uint) {
        return _citizenCount;
    }

    function getGatekeeperCount() public constant returns(uint) {
        return _gatekeeperCount;
    }

    function getProposalDecideThresholdPercent() public constant returns(uint) {
        return _parameters.proposalDecideThresholdPercent;
    }

    function isGatekeeper(address addr) constant returns (bool) {
        return isCitizen(addr) && _citizens[addr].isGatekeeper;
    }

    function isCitizen(address addr) constant returns (bool) {
        return _citizens[addr].isExistent;
    }

    function getMaxProposalId() constant returns (uint) {
        return _nextProposalId;
    }

    function getProposalBasicDetails(uint proposalId) public constant returns (uint id, bool isExistent, ProposalDecision decision, bool hasSenderVoted, ProposalType typ, uint expiryTime) {
        return (proposalId, _proposals[proposalId].isExistent, _proposals[proposalId].decision, _proposals[proposalId].hasVoted[msg.sender], _proposals[proposalId].typ, _proposals[proposalId].expiryTime);
    }

    function getProposalVotes(uint proposalId) public constant returns (uint id, uint voteCountYes, uint voteCountNo) {
        return (proposalId, _proposals[proposalId].voteCountYes, _proposals[proposalId].voteCountNo);
    }

    function getAppointGatekeeperProposal(uint proposalId) public constant returns ( // apparently you cannot have more than 8 return values!!
        uint id, 
        address appointGatekeeperId)
    {
        id = proposalId;
        appointGatekeeperId = _proposals[id].appointGatekeeperId;

        return;
    }

    function getAddCitizenProposal(uint proposalId) public constant returns ( // apparently you cannot have more than 8 return values!!
        uint id, 
        address addCitizenId,
        string supportingEvidenceSwarmAddress)
    {
        id = proposalId;
        addCitizenId = _proposals[id].addCitizenId;
        supportingEvidenceSwarmAddress = _proposals[id].supportingEvidenceSwarmAddress;

        return;
    }
   
    //
    // ERC223
    //

    function name() constant returns (string) {
        return _name;
    }

    function symbol() constant returns (string) {
        return _symbol;
    }

    function decimals() constant returns (uint8) {
        return _decimals;
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

    function decideProposal(uint proposalId, ProposalDecision decision) private {        
        
        assert(decision != ProposalDecision.Undecided);

        var proposal = _proposals[proposalId];
                
        assert(proposal.isExistent);
        assert(proposal.decision == ProposalDecision.Undecided);
        
        proposal.decision = decision;

        if (decision == ProposalDecision.Accepted) {
            if (proposal.typ == ProposalType.AppointGatekeeper) {
                appointGatekeeper(proposal.appointGatekeeperId);
            } else if (proposal.typ == ProposalType.DismissGatekeeper) {
                dismissGatekeeper(proposal.dismissGatekeeperId);
            } else if (proposal.typ == ProposalType.AddCitizen) {
                addCitizen(proposal.addCitizenId);
            } else if (proposal.typ == ProposalType.RemoveCitizen) {
                removeCitizen(proposal.removeCitizenId);
            } else if (proposal.typ == ProposalType.SetContractParameters) {
                setContractParameters(proposal.setContractParametersParameters);
            } else if (proposal.typ == ProposalType.CreateMoney) {
                createMoney(proposal.createMoneyAmountPerAccount);
            } else if (proposal.typ == ProposalType.TaxWealth) {
                taxWealth(proposal.taxWealthPercent);
            } else if (proposal.typ == ProposalType.SpendPublicMoney) {
                spendPublicMoney(proposal.spendPublicMoneyTo, proposal.spendPublicMoneyAmount);
            } else {
                revert();
            }
        }

        OnProposalDecided(proposalId);
    }

    function appointGatekeeper(address id) private {
        assert(isCitizen(id));
        assert(!isGatekeeper(id));

        _citizens[id].isGatekeeper = true;
        _gatekeeperCount++;
    }

    function dismissGatekeeper(address id) private {
        assert(isCitizen(id));
        assert(isGatekeeper(id));

        _citizens[id].isGatekeeper = false;
        _gatekeeperCount--;
    }

    function addCitizen(address id) private {
        assert(!isCitizen(id));
        
        _citizens[id].owner = id;
        _citizens[id].isExistent = true;
        _citizens[id].isGatekeeper = false;
        _citizens[id].balance = _parameters.initialAccountBalance;

        _totalSupply += _parameters.initialAccountBalance;        
        _citizenCount++;
        _allCitizenOwnersEver.push(id); // todo what if citizen is removed and re-added?
    }

    function removeCitizen(address id) private {
        assert(isCitizen(id));
        assert(_totalSupply >= _citizens[id].balance);

        _totalSupply -= _citizens[id].balance;
        _citizenCount--;
        _citizens[id].isExistent = false;
    }

    function setContractParameters(ContractParameters newContractParameters) private {
        _parameters.initialAccountBalance = newContractParameters.initialAccountBalance;
        _parameters.proposalDecideThresholdPercent = newContractParameters.proposalDecideThresholdPercent;
        _parameters.proposalTimeLimit = newContractParameters.proposalTimeLimit;
    }

    function createMoney(uint amountPerAccount) private {

        bytes memory empty;

        for (uint i = 0; i < _allCitizenOwnersEver.length; i++) {
            var accountOwner = _allCitizenOwnersEver[i];

            if (_citizens[accountOwner].isExistent) {
                if (_citizens[accountOwner].balance + amountPerAccount > _citizens[accountOwner].balance) {
                    _citizens[accountOwner].balance += amountPerAccount;
                    _totalSupply += amountPerAccount;
                    Transfer(PUBLIC_ACCOUNT, accountOwner, amountPerAccount, empty);
                }
            }
        }
    }

    function taxWealth(uint percent) private {
        for (uint i = 0; i < _allCitizenOwnersEver.length; i++) {
            var accountOwner = _allCitizenOwnersEver[i];

            if (_citizens[accountOwner].isExistent) {
                var amountToTax = (percent * _citizens[accountOwner].balance) / 100;
                transferInternal(accountOwner, PUBLIC_ACCOUNT, amountToTax);
            }
        }
    }

    function spendPublicMoney(address to, uint amount) private {
        transferInternal(PUBLIC_ACCOUNT, to, amount);
    }

    function transferInternal(address from, address to, uint amount) private {
        bytes memory empty;
        transferInternal(from, to, amount, empty);
    }

    function transferInternal(address from, address to, uint amount, bytes data) private {
        assert(isCitizen(from));        
        assert(isCitizen(to));
        assert(_citizens[from].balance >= amount);
        assert(_citizens[to].balance + amount > _citizens[to].balance);

        _citizens[from].balance -= amount;
        _citizens[to].balance += amount;

        Transfer(from, to, amount, data);
    }

    modifier onlyGatekeeper {
        require(_gatekeeperCount == 0 || isGatekeeper(msg.sender));
        _;
    }

    modifier onlyCitizen {
        require(isCitizen(msg.sender));
        _;
    }
}