pragma solidity ^0.4.9;

import "./Receiver_Interface.sol";
import "./ERC223_Interface.sol";

 /* https://github.com/LykkeCity/EthereumApiDotNetCore/blob/master/src/ContractBuilder/contracts/token/SafeMath.sol */
contract SafeMath {
    uint256 constant public MAX_UINT256 =
    0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;

    function safeAdd(uint256 x, uint256 y) constant internal returns (uint256 z) {
        require(x < MAX_UINT256 - y);
        return x + y;
    }

    function safeSub(uint256 x, uint256 y) constant internal returns (uint256 z) {
        require(x >= y);
        return x - y;
    }

    function safeMul(uint256 x, uint256 y) constant internal returns (uint256 z) {
        if (y == 0) {
            return 0;
        }
        require(x <= MAX_UINT256 / y);
        return x * y;
    }

    function SafeMath() public payable {

    }
}

contract VillageCoin is ERC223, SafeMath {

    address PUBLIC_ACCOUNT = 0; 

    struct ContractParameters {
        uint initialAccountBalance;
        uint proposalDecideThresholdPercent;
        uint proposalTimeLimit;
    }
    
    struct Account {        
        address owner;
        uint balance;
        bool isExistent;
    }  

    struct Manager {
        address id;
        bool isExistent;
    }

    enum ProposalType { 
        CreateManager, 
        DeleteManager, 
        CreateAccount, 
        DeleteAccount, 
        SetContractParameters, 
        CreateMoney, 
        TaxWealth, 
        SpendPublicMoney 
        }

    enum ProposalState {
        NonExistent,
        Undecided,
        Accepted,
        Rejected
    }

    struct Proposal {
        uint id;
        ProposalType typ;
        uint voteCountYes;
        uint voteCountNo;
        mapping(address=>bool) hasVoted;
        bool isExistent;
        uint expiryTime;

        address createManagerId;

        address deleteManagerId;

        address createAccountOwner;        

        address deleteAccountOwner;

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
    ContractParameters _parameters;

    mapping(address=>Manager) _managers;
    uint _managerCount;

    mapping(address=>Account) _accounts;
    uint _accountCount;
    address[] _allAcountOwnersEver;

    uint _nextProposalId;
    mapping(uint=>Proposal) _proposals;

    uint256 _totalSupply;

    function VillageCoin(string name, string symbol, uint8 decimals) payable {
        _name = name;
        _symbol = symbol;
        _decimals = decimals;
        _parameters.initialAccountBalance = 1000;
        _parameters.proposalDecideThresholdPercent = 60;
        _parameters.proposalTimeLimit = 30 days;

        createManager(msg.sender);
        createAccount(PUBLIC_ACCOUNT);
        createAccount(msg.sender);
    }

    //
    // Management Methods
    //

    function proposeCreateManager(address id) public onlyManager {
        require(!_managers[id].isExistent);

        var proposalId = _nextProposalId++;
        assert(!_proposals[proposalId].isExistent);

        _proposals[proposalId].isExistent = true;
        _proposals[proposalId].expiryTime = now + _parameters.proposalTimeLimit;
        _proposals[proposalId].typ = ProposalType.CreateManager;
        _proposals[proposalId].createManagerId = id;

        OnProposalCreated(proposalId);
    }

    function proposeDeleteManager(address id) public onlyManager {
        require(_managers[id].isExistent);

        var proposalId = _nextProposalId++;
        assert(!_proposals[proposalId].isExistent);

        _proposals[proposalId].isExistent = true;
        _proposals[proposalId].expiryTime = now + _parameters.proposalTimeLimit;
        _proposals[proposalId].typ = ProposalType.DeleteManager;
        _proposals[proposalId].deleteManagerId = id;

        OnProposalCreated(proposalId);
    }

    function proposeCreateAccount(address owner, string supportingEvidenceSwarmAddress) public {
        require(!_accounts[owner].isExistent);

        var proposalId = _nextProposalId++;
        assert(!_proposals[proposalId].isExistent);

        _proposals[proposalId].isExistent = true;
        _proposals[proposalId].expiryTime = now + _parameters.proposalTimeLimit;
        _proposals[proposalId].typ = ProposalType.CreateAccount;
        _proposals[proposalId].createAccountOwner = owner;
        _proposals[proposalId].supportingEvidenceSwarmAddress = supportingEvidenceSwarmAddress;

        OnProposalCreated(proposalId);
    }

    function proposeDeleteAccount(address owner) public onlyManager {
        require(_accounts[owner].isExistent);

        var proposalId = _nextProposalId++;
        assert(!_proposals[proposalId].isExistent);

        _proposals[proposalId].isExistent = true;
        _proposals[proposalId].expiryTime = now + _parameters.proposalTimeLimit;
        _proposals[proposalId].typ = ProposalType.DeleteAccount;
        _proposals[proposalId].deleteAccountOwner = owner;

        OnProposalCreated(proposalId);
    }

    function proposeSetContractParameters (
        uint initialAccountBalance,
        uint proposalDecideThresholdPercent,
        uint proposalTimeLimitDays) public onlyManager 
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

    function proposeCreateMoney(uint amountPerAccount) public onlyManager {
        var proposalId = _nextProposalId++;
        assert(!_proposals[proposalId].isExistent);

        _proposals[proposalId].isExistent = true;
        _proposals[proposalId].expiryTime = now + _parameters.proposalTimeLimit;
        _proposals[proposalId].typ = ProposalType.CreateMoney;
        _proposals[proposalId].createMoneyAmountPerAccount = amountPerAccount;

        OnProposalCreated(proposalId);
    }

    function proposeTaxWealth(uint percent) public onlyManager {
        var proposalId = _nextProposalId++;
        assert(!_proposals[proposalId].isExistent);

        _proposals[proposalId].isExistent = true;
        _proposals[proposalId].expiryTime = now + _parameters.proposalTimeLimit;
        _proposals[proposalId].typ = ProposalType.TaxWealth;
        _proposals[proposalId].taxWealthPercent = percent;

        OnProposalCreated(proposalId);
    }

    function proposeSpendPublicMoney(address to, uint amount) public onlyManager {
        var proposalId = _nextProposalId++;
        assert(!_proposals[proposalId].isExistent);

        _proposals[proposalId].isExistent = true;
        _proposals[proposalId].expiryTime = now + _parameters.proposalTimeLimit;
        _proposals[proposalId].typ = ProposalType.SpendPublicMoney;
        _proposals[proposalId].spendPublicMoneyTo = to;
        _proposals[proposalId].spendPublicMoneyAmount = amount;

        OnProposalCreated(proposalId);
    }

    function voteOnProposal(uint proposalId, bool isYes) public {
        require(_proposals[proposalId].isExistent);
        require(!_proposals[proposalId].hasVoted[msg.sender]);
        
        if (_proposals[proposalId].typ == ProposalType.CreateAccount) {
            require(isManager(msg.sender));
        } else {
            require(hasAccount(msg.sender));
        }

        _proposals[proposalId].hasVoted[msg.sender] = true;        
        if (isYes) {
            _proposals[proposalId].voteCountYes++;
        } else {
            _proposals[proposalId].voteCountNo++;
        }
    }

    function tryDecideProposal(uint proposalId) public {

        var state = getProposalState(proposalId);

        assert(state != ProposalState.NonExistent);

        if (state == ProposalState.Accepted) {
            decideProposal(proposalId, true);
        } else if (state == ProposalState.Rejected) {
            decideProposal(proposalId, false);
        }
    }

    function getProposalState(uint proposalId) private constant returns (ProposalState) {
        var proposal = _proposals[proposalId];

        if (!proposal.isExistent) {
            return ProposalState.NonExistent;
        }

        var totalVoters = proposal.typ == ProposalType.CreateAccount ? _managerCount : _accountCount;

        var percentYes = ((proposal.voteCountYes * 100) / totalVoters);
        var percentNo = ((proposal.voteCountNo * 100) / totalVoters);

        if (percentYes >= _parameters.proposalDecideThresholdPercent) {
            return ProposalState.Accepted;
        } else if (percentNo >= _parameters.proposalDecideThresholdPercent) {
            return ProposalState.Rejected;
        } else if (now > proposal.expiryTime) {
            return ProposalState.Rejected;
        }

        return ProposalState.Undecided;
    }

    //
    // Views
    //

    function isManager(address addr) constant returns (bool) {
        return _managers[addr].isExistent;
    }

    function hasAccount(address addr) constant returns (bool) {
        return _accounts[addr].isExistent;
    }

    function getMaxProposalId() constant returns (uint) {
        return _nextProposalId;
    }

    function getProposalBasicDetails(uint proposalId) constant onlyManager returns (uint id, bool isExistent, bool hasSenderVoted, ProposalType typ, ProposalState state) {
        return (proposalId, _proposals[proposalId].isExistent, _proposals[proposalId].hasVoted[msg.sender], _proposals[proposalId].typ, getProposalState(proposalId));
    }

    function getCreateManagerProposal(uint proposalId) constant onlyManager returns ( // apparently you cannot have more than 8 return values!!
        uint id, 
        address createManagerId)
        {
            id = proposalId;
            createManagerId = _proposals[id].createManagerId;

            return;
        }

    function getCreateAccountProposal(uint proposalId) constant onlyManager returns ( // apparently you cannot have more than 8 return values!!
        uint id, 
        address createAccountOwner,
        string supportingEvidenceSwarmAddress)
        {
            id = proposalId;
            createAccountOwner = _proposals[id].createAccountOwner;
            supportingEvidenceSwarmAddress = _proposals[id].supportingEvidenceSwarmAddress;

            return;
        }

    //         function getProposal(uint proposalId) constant onlyManager returns ( // apparently you cannot have more than 8 return values!!
    //     uint id, 
    //     ProposalType typ, 
    //     uint voteCountYes, 
    //     uint voteCountNo, 
    //     bool hasSenderVoted,
    //     bool isExistent,
    //     uint expiryTime,
    //     address createManagerId,
    //     address deleteManagerId,
    //     address createAccountOwner,
    //     address deleteAccountOwner,
    //     uint contractParametersInitialAccountBalance,
    //     uint contractParametersProposalDecideThresholdPercent,
    //     uint contractParametersProposalTimeLimit,
    //     uint createMoneyAmountPerAccount,
    //     uint taxWealthPercent,
    //     address spendPublicMoneyTo,
    //     uint spendPublicMoneyAmount
    //  )
    //     {
    //         id = proposalId;
    //         typ = _proposals[id].typ; 
    //       //  voteCountYes = _proposals[id].voteCountYes;
    //       //  voteCountNo = _proposals[id].voteCountNo; 
    //         hasSenderVoted = _proposals[id].hasVoted[msg.sender];
    //         isExistent = _proposals[id].isExistent;
    //         expiryTime = _proposals[id].expiryTime;
    //         createManagerId = _proposals[id].createManagerId;
    //       //  deleteManagerId = _proposals[id].deleteManagerId;
    //       //  createAccountOwner = _proposals[id].createAccountOwner;
    //       //  deleteAccountOwner = _proposals[id].deleteAccountOwner;
    //       //  contractParametersInitialAccountBalance = _proposals[id].setContractParametersParameters.initialAccountBalance;
    //       //  contractParametersProposalDecideThresholdPercent = _proposals[id].setContractParametersParameters.proposalDecideThresholdPercent;
    //       //  contractParametersProposalTimeLimit = _proposals[id].setContractParametersParameters.proposalTimeLimit;
    //       //  createMoneyAmountPerAccount = _proposals[id].createMoneyAmountPerAccount;
    //        // taxWealthPercent = _proposals[id].taxWealthPercent;
    //       //  spendPublicMoneyTo = _proposals[id].spendPublicMoneyTo;
    //       //  spendPublicMoneyAmount = _proposals[id].spendPublicMoneyAmount;

    //         return;
    //     }

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
    function transfer(address to, uint value, bytes data, string customFallback) public onlyUser returns (bool success) {
        
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
    function transfer(address to, uint value, bytes data) public onlyUser returns (bool success) {
        
        if (isContract(to)) {
            return transferToContract(to, value, data);
        } else {
            return transferToAddress(to, value, data);
        }
    }
  
    // Standard function transfer similar to ERC20 transfer with no _data .
    // Added due to backwards compatibility reasons .
    function transfer(address to, uint value) public onlyUser returns (bool success) {
        
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
    function transferToAddress(address to, uint value, bytes data) private onlyUser returns (bool success) {
        transferInternal(msg.sender, to, value, data);
        return true;
    }
  
    //function that is called when transaction target is a contract
    function transferToContract(address to, uint value, bytes data) private onlyUser returns (bool success) {
        transferInternal(msg.sender, to, value, data);
        ContractReceiver receiver = ContractReceiver(to);
        receiver.tokenFallback(msg.sender, value, data);
        return true;
    }

    function balanceOf(address owner) public constant returns (uint balance) {
        require(_accounts[owner].isExistent);
        return _accounts[owner].balance;
    }

    //
    // Internal Stuff
    //

    function decideProposal(uint proposalId, bool isYes) private onlyUser {        
        
        var proposal = _proposals[proposalId];
        
        require(proposal.isExistent);
        
        proposal.isExistent = false;

        if (isYes) {
            if (proposal.typ == ProposalType.CreateManager) {
                createManager(proposal.createManagerId);
            } else if (proposal.typ == ProposalType.DeleteManager) {
                deleteManager(proposal.deleteManagerId);
            } else if (proposal.typ == ProposalType.CreateAccount) {
                createAccount(proposal.createAccountOwner);
            } else if (proposal.typ == ProposalType.DeleteAccount) {
                deleteAccount(proposal.deleteAccountOwner);
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

    // function createProposal(Proposal proposal) private onlyManager {
    //     proposal.id = _nextProposalId++;
    //     proposal.isExistent = true;
    //     _proposals[proposal.id] = proposal;

    //     OnProposalCreated(proposal.id);
    // }    

    function createManager(address id) private {
        require(!_managers[id].isExistent);

        _managers[id].id = id;
        _managers[id].isExistent = true;
        _managerCount++;
    }

    function deleteManager(address id) private {
        require(_managers[id].isExistent);

        _managers[id].isExistent = false;
        _managerCount--;
    }

    function createAccount(address owner) private {
        require(!_accounts[owner].isExistent);
        
        _accounts[owner].owner = owner;
        _accounts[owner].isExistent = true;
        _accounts[owner].balance = _parameters.initialAccountBalance;

        _totalSupply += _parameters.initialAccountBalance;
        _accountCount++;
        _allAcountOwnersEver.push(owner);
    }

    function deleteAccount(address owner) private {
        require(_accounts[owner].isExistent);
        assert(_totalSupply >= _accounts[owner].balance);

        _totalSupply -= _accounts[owner].balance;
        _accountCount--;
        _accounts[owner].isExistent = false;
    }

    function setContractParameters(ContractParameters newContractParameters) private onlyManager {
        _parameters.initialAccountBalance = newContractParameters.initialAccountBalance;
        _parameters.proposalDecideThresholdPercent = newContractParameters.proposalDecideThresholdPercent;
        _parameters.proposalTimeLimit = newContractParameters.proposalTimeLimit;
    }

    function createMoney(uint amountPerAccount) private {

        bytes memory empty;

        for (uint i = 0; i < _allAcountOwnersEver.length; i++) {
            var accountOwner = _allAcountOwnersEver[i];

            if (_accounts[accountOwner].isExistent) {
                if (_accounts[accountOwner].balance + amountPerAccount > _accounts[accountOwner].balance) {
                    _accounts[accountOwner].balance += amountPerAccount;
                    _totalSupply += amountPerAccount;
                    Transfer(PUBLIC_ACCOUNT, accountOwner, amountPerAccount, empty);
                }
            }
        }
    }

    function taxWealth(uint percent) private {
        for (uint i = 0; i < _allAcountOwnersEver.length; i++) {
            var accountOwner = _allAcountOwnersEver[i];

            if (_accounts[accountOwner].isExistent) {
                var amountToTax = (percent * _accounts[accountOwner].balance) / 100;
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
        require(_accounts[from].isExistent);        
        require(_accounts[to].isExistent);
        require(_accounts[from].balance >= amount);
        require(_accounts[to].balance + amount > _accounts[to].balance);

        _accounts[from].balance -= amount;
        _accounts[to].balance += amount;

        Transfer(from, to, amount, data);
    }

    modifier onlyManager {
        require(_managerCount == 0 || _managers[msg.sender].isExistent);
        _;
    }

    modifier onlyUser {
        require(_accounts[msg.sender].isExistent);
        _;
    }
}