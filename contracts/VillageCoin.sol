pragma solidity ^0.4.9;

import "./SafeMathLib.sol";
import "./ParameterLib.sol";
import "./ReferendumLib.sol";
import "./TokenLib.sol";
import "./AccountLib.sol";
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

    //
    // Constants
    //

    bytes32 constant public PRM_NAME = sha3("PRM_NAME");
    bytes32 constant public PRM_SYMBOL = sha3("PRM_SYMBOL");
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

    // Eternal storage for contract data
    Storage _storage;

    // The address of the priviliged user that can create accounts and do some other special things
    address public _gatekeeper;
    // Next round of taxes cannot be applied before this time
    uint public _nextTaxTime;
    // A message to display at the top of the website for special annoucements etc.
    string public _announcementMessage; 

    //
    // Events
    //

    event OnProposalCreated(uint proposalId);
    //event OnProposalDecided(uint proposalId);  

    //
    // Constructor 
    //        

    function VillageCoin(address storageAddr) payable {        
        _gatekeeper = msg.sender;
        _storage = Storage(storageAddr);
    }

    //
    // Gatekeeper actions
    //

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
    function registerCitizen(address addr, bytes32 username) onlyGatekeeper public {
        AccountLib.registerCitizen(_storage, addr, username);
        TokenLib.init(_storage, addr, getNumberParameter(PRM_INITIAL_ACCOUNT_BALANCE));
    }

    //
    // Public actions
    //

    // If taxes are now due then take/give all taxes, otherwise do nothing
    function applyTaxesIfDue() public {
        // var isDue = now > _nextTaxTime;
        // if (!isDue) {
        //     return;
        // }

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

        var enact = ReferendumLib.tryDecide(_storage, proposalId, AccountLib.getPopulation(_storage), getNumberParameter(PRM_PROPOSAL_DECIDE_THRESHOLD_PERCENT));

        if (enact) {
            ProposalLib.enactProposal(_storage, proposalId);
        }
    }

    //
    // Citizen actions
    //

    // See ProposalLib.sol
    function proposePackage(uint[] partIds, bytes32 supportingEvidence) public onlyCitizen {
        uint proposalId = ProposalLib.proposePackage(_storage, partIds, supportingEvidence);
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

        uint proposalId = ProposalLib.proposeSetParameter(_storage, parameterName, stringValue, numberValue, supportingEvidence, isPartOfPackage);
        afterCreateProposal(proposalId);      
    }

    // See ProposalLib.sol
    function proposeCreateMoney(uint amount, bytes32 supportingEvidence, bool isPartOfPackage) public onlyCitizen {
        uint proposalId = ProposalLib.proposeCreateMoney(_storage, amount, supportingEvidence, isPartOfPackage);
        afterCreateProposal(proposalId);
    }

    // See ProposalLib.sol
    function proposeDestroyMoney(uint amount, bytes32 supportingEvidence, bool isPartOfPackage) public onlyCitizen {
        uint proposalId = ProposalLib.proposeDestroyMoney(_storage, amount, supportingEvidence, isPartOfPackage);
        afterCreateProposal(proposalId);
    }

    // See ProposalLib.sol
    function proposePayCitizen(address citizen, uint amount, bytes32 supportingEvidence, bool isPartOfPackage) public onlyCitizen {
        uint proposalId = ProposalLib.proposePayCitizen(_storage, citizen, amount, supportingEvidence, isPartOfPackage);
        afterCreateProposal(proposalId);
    }

    // See ProposalLib.sol
    function proposeFineCitizen(address citizen, uint amount, bytes32 supportingEvidence, bool isPartOfPackage) public onlyCitizen {
        uint proposalId = ProposalLib.proposeFineCitizen(_storage, citizen, amount, supportingEvidence, isPartOfPackage);        
        afterCreateProposal(proposalId);
    }
    
    // See ReferendumLib.sol
    function voteOnProposal(uint proposalId, bool isYes) public onlyCitizen {
        ReferendumLib.vote(_storage, proposalId, msg.sender, isYes);        
    }

    //
    // Views
    //

        //
        // Proposals
        //

    function getNextProposalId() public constant returns(uint) {
        return ProposalLib.getNextId(_storage);
    }

    // Return all details of specified proposal
    // Because of a technical restriction is it not possible to return all the fields of a Proposal from a seingle function
    // so this is split into A and B parts that together return all Proposal fields
    function getProposalA(uint proposalId) public constant returns(
        uint typ, 
        address proposer, 
        bool isExistent,
        bytes32 stringParam1,
        bytes32 stringParam2) 
        {
            (typ, proposer, isExistent, stringParam1, stringParam2) = ProposalLib.getProposalA(_storage, proposalId);
            return;
    }

    // Return all details of specified proposal
    // Because of a technical restriction is it not possible to return all the fields of a Proposal from a seingle function
    // so this is split into A and B parts that together return all Proposal fields
    function getProposalB(uint proposalId) public constant returns(         
        uint numberParam1,              
        address addressParam1,                    
        bytes32 supportingEvidenceUrl,
        bool isPartOfPackage,
        bool isAssignedToPackage) 
        {
            (numberParam1, addressParam1, supportingEvidenceUrl, isPartOfPackage, isAssignedToPackage) = ProposalLib.getProposalB(_storage, proposalId);
            //assert(numberParam1 != 0);
            return;
    }

    // Return the number of parts in the specified package proposal
    function getPackagePartCount(uint proposalId) public constant returns(uint) {
        return ProposalLib.getPackagePartCount(_storage, proposalId);
    }

    // Return the id of the part with specified index within the specified package proposal
    function getPackagePart(uint proposalId, uint i) public constant returns(uint) {
        return ProposalLib.getPackagePart(_storage, proposalId, i);
    }

        //
        // Referendums
        //

    function getReferendum(uint id) returns(bool isExistent, uint state, uint expiryTime, uint voteCountYes, uint voteCountNo, bool hasSenderVoted) {
        (isExistent, state, expiryTime, voteCountYes, voteCountNo) = ReferendumLib.get(_storage, id);
        hasSenderVoted = ReferendumLib.hasVoted(_storage, id, msg.sender);
        return;
    } 

    function getHasSenderVoted(uint proposalId) returns(bool) {
        return ReferendumLib.hasVoted(_storage, proposalId, msg.sender);
    }

        //
        // Citizens
        //

    function getNextCitizenId() public constant returns (uint) {
        return AccountLib.getNextId(_storage);
    }

    function getPopulation() public constant returns(uint) {
        return AccountLib.getPopulation(_storage);
    }

    function getCitizen(uint id) public constant returns (bytes32 username, address addr, bool isExistent) {
        (username, addr, isExistent) = AccountLib.get(_storage, id);
    }

    function isCitizen(address addr) public constant returns(bool) {
        return AccountLib.isCitizen(_storage, addr);
    }

    // Return all details of citizen with specified username
    // Doesnt throw if they dont exist
    function getCitizenByUsername(bytes32 username) public constant returns(
        bool isExistent,
        address addr,
        uint balance)
    {
        (addr, isExistent) = AccountLib.get(_storage, username);
        balance = TokenLib.balanceOf(_storage, addr);
        return;
    }

    // Return all details of citizen with specified address
    // Doesnt throw if they dont exist
    function getCitizenByAddress(address addr) public constant returns(
        bool isExistent,
        bytes32 username,
        uint balance)
    {
        (username, isExistent) = AccountLib.get(_storage, addr);
        balance = TokenLib.balanceOf(_storage, addr);
        return;
    }

        //
        // Tax
        //

    // Return the tax due if the specified Citizen makes a proposal
    function calculateProposalTax(address proposer) public constant returns(uint) {

        uint proposalTaxFlat = getNumberParameter(PRM_PROPOSAL_TAX_FLAT);
        uint balance = TokenLib.balanceOf(_storage, proposer);
        uint proposalTaxPercent = getNumberParameter(PRM_PROPOSAL_TAX_PERCENT);

        return TaxLib.calculateProposalTax(proposalTaxFlat, proposalTaxPercent, balance);
    }

    // Return the tax due if the specified Citizen makes the specified transaction
    function calculateTransactionTax(address from, address to, uint amount) public constant returns(uint) {
        uint transactionTaxFlat = getNumberParameter(PRM_TRANSACTION_TAX_FLAT);
        uint transactionTaxPercent = getNumberParameter(PRM_TRANSACTION_TAX_PERCENT);

        return TaxLib.calculateTransactionTax(amount, from, to, transactionTaxFlat, transactionTaxPercent);
    }

        //
        // Parameters
        //
    
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

    //
    // ERC20
    //

    event Transfer(address indexed from, address indexed to, uint amount);
  
    function transfer(address to, uint amount) public returns (bool success) {
        AccountLib.ensureAccountIsRegistered(_storage, msg.sender);
        AccountLib.ensureAccountIsRegistered(_storage, to);
        uint transactionTax = calculateTransactionTax(msg.sender, to, amount);
        TokenLib.transfer(_storage, msg.sender, TokenLib.getPublicAccount(), transactionTax);
        TokenLib.transfer(_storage, msg.sender, to, amount);  
    }

    function transferFrom(address from, address to, uint value) public returns (bool success) {
        return false; // not supported
    }

    function balanceOf(address owner) constant public returns (uint balance) {
        return TokenLib.balanceOf(_storage, owner);
    }

    function approve(address spender, uint value) public returns (bool success) {
        return false; // not supported
    }

    function allowance(address owner, address spender) constant public returns (uint remaining) {
        return 0; // not supported
    }

    function name() constant public returns (string) {
        return bytes32ToString(getStringParameter(PRM_NAME));
    }

    function symbol() constant public returns (string) {
        return bytes32ToString(getStringParameter(PRM_SYMBOL));
    }

    function decimals() constant public returns (uint8) {
        return uint8(getNumberParameter(PRM_DECIMALS));
    }

    function totalSupply() constant public returns (uint256) {
        return TokenLib.getTotalSupply(_storage);
    }

    //
    // Internal Stuff
    //

    // Only used to implement name() and symbol() from ERC20. Internally they are stored as bytes32
    function bytes32ToString(bytes32 x) constant returns (string) {
        bytes memory bytesString = new bytes(32);
        uint charCount = 0;
        for (uint j = 0; j < 32; j++) {
            byte char = byte(bytes32(uint(x) * 2 ** (8 * j)));
            if (char != 0) {
                bytesString[charCount] = char;
                charCount++;
            }
        }
        bytes memory bytesStringTrimmed = new bytes(charCount);
        for (j = 0; j < charCount; j++) {
            bytesStringTrimmed[j] = bytesString[j];
        }
        return string(bytesStringTrimmed);
    }

    // Stuff that needs to happen after a proposal is created:
    // - change proposal tax to the sender
    // - start a referendum
    // (Except for parts of packages)
    function afterCreateProposal(uint proposalId) private {
        bool isPartOfPackage = ProposalLib.getIsPartOfPackage(_storage, proposalId);
        if (isPartOfPackage) {
            return;
        }
        payProposalTax();
        ReferendumLib.init(_storage, proposalId, getNumberParameter(PRM_PROPOSAL_TIME_LIMIT_DAYS) * 1 days);
    }

    function payProposalTax() private {
        uint tax = calculateProposalTax(msg.sender);
        TokenLib.transfer(_storage, msg.sender, TokenLib.getPublicAccount(), tax);
    }

    // Each type of tax is a token transfer made periodically from each citizen to the public account 
    // The amount transfered for Poll Tax is the value of the parameter 'taxPollTax'
    // If a citizen does not have the required funds then their balance is emptied    
    function applyPollTax() private {
        var pollTaxAmount = getNumberParameter(PRM_POLL_TAX);
        if (pollTaxAmount == 0) {
            return;
        }

        var maxAccountId = AccountLib.getNextId(_storage);
        for (uint i = 1; i < maxAccountId; i++) {
            bytes32 username;
            address addr; 
            bool isExistent;
            (username, addr, isExistent) = AccountLib.get(_storage, i);
            if (!isExistent) {
                continue;
            }
            TokenLib.transferAsMuchAsPossibleOf(_storage, addr, TokenLib.getPublicAccount(), pollTaxAmount);
        }
    }

    // Each type fo tax is a token transfer made periodically from each citizen to the public account 
    // The amount transfered for Wealth Tax is the Citizen's balance multiplied by the percentage parameter 'taxWealthTaxPercent'   
    function applyWealthTax() private {

        var wealthTaxPercent = getNumberParameter(PRM_WEALTH_TAX_PERCENT);
        if (wealthTaxPercent == 0) {
            return;
        }

        var maxAccountId = AccountLib.getNextId(_storage);
        for (uint i = 1; i < maxAccountId; i++) {
            bytes32 username;
            address addr; 
            bool isExistent;
            (username, addr, isExistent) = AccountLib.get(_storage, i);
            if (!isExistent) {
                continue;
            }
            var wealthTaxAmount = TaxLib.calculateWealthTax(TokenLib.balanceOf(_storage, addr), wealthTaxPercent);
            TokenLib.transfer(_storage, addr, TokenLib.getPublicAccount(), wealthTaxAmount); 
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

        var totalValue = basicIncomeAmount.times(AccountLib.getPopulation(_storage));
        var publicFunds = TokenLib.balanceOf(_storage, TokenLib.getPublicAccount());
        if (totalValue > publicFunds) {
            basicIncomeAmount = publicFunds / AccountLib.getPopulation(_storage);
        }

        var maxAccountId = AccountLib.getNextId(_storage);
        for (uint i = 1; i < maxAccountId; i++) {
            bytes32 username;
            address addr; 
            bool isExistent;
            (username, addr, isExistent) = AccountLib.get(_storage, i);
            if (!isExistent) {
                continue;
            }
            if (username == 0) {
                continue;
            }
            TokenLib.transfer(_storage, TokenLib.getPublicAccount(), addr, basicIncomeAmount);  
        }
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