pragma solidity ^0.4.9;

import "./SafeMathLib.sol";

// A proposal is a suggestion to make specific change or set of changes to the state of the contract
// There are several types of proposal that make different types of changes
// The Proposal object can repreesent any of the types of proposal
// Proposals is a collection of Proposal objects
// Items can be added to the Proposals collection using the proposeXXX functions
//
// Actual implementation of proposal changes is in VillageCoin.sol
library ProposalLib {

    using SafeMathLib for uint;

    event OnProposalCreated(uint proposalId);

    enum ProposalType { 
        SetParameter, 
        CreateMoney, 
        DestroyMoney,
        PayCitizen, 
        FineCitizen,
        Package
        }

    struct Proposal {
        bool isExistent;

        ProposalType typ;
        address proposer;                
        string supportingEvidenceUrl;

        // these generic parameters have different meanings for different types of proposal
        string stringParam1;
        string stringParam2;        
        uint numberParam1;                
        address addressParam1;  
        
        bool isPartOfPackage;
        bool isAssignedToPackage;
        uint[] packageParts;
    }

    struct Proposals {
        uint nextProposalId;
        mapping(uint=>Proposal) proposals;
    }

    // create a new Proposal of type Package
    // a Package Proposal is a Proposal that contains a number of other Proposals called 'Parts'
    // If a Package Proposal is Accepted then all of its Parts are enacted
    // Parts cannot themselves be Package Proposals
    // Parts must be marked as isPartOfPacakge
    // Parts must NOT be maked as isAssignedToPackage
    // This function sets isAssignedToPackage to true for all the specified parts
    function proposePackage(Proposals storage self, uint[] partIds, string supportingEvidence) public returns(uint) {

        require(partIds.length <= 32);

        var proposalId = createProposal(self, ProposalType.Package, supportingEvidence, "", "", 0, 0x0, false);
        
        for (uint i = 0; i < partIds.length; i++) {
            var partId = partIds[i];
            var part = self.proposals[partId];
            require(part.isExistent);
            require(part.isPartOfPackage);
            require(!part.isAssignedToPackage);
            require(part.typ != ProposalType.Package);
            require(part.proposer == msg.sender);

            self.proposals[proposalId].packageParts.push(partId);
            self.proposals[partId].isAssignedToPackage = true;
        }

        return proposalId;
    }

    // Create a new Proposal of type SetParameter
    // If a SetParameter Proposal is Accepted then the named Parameter will be set to the specified value
    // Note: this function does not check the validity of the input parameters so you need to do that elsewhere
    function proposeSetParameter (
        Proposals storage self, 
        string parameterName,
        string stringValue,
        uint numberValue,
        string supportingEvidence,
        bool isPartOfPackage
    ) public returns(uint)
    {
        return createProposal(self, ProposalType.SetParameter, supportingEvidence, parameterName, stringValue, numberValue, 0x0, isPartOfPackage);
    }

    // Create a new Proposal of type CreateMoney
    // If the Proposal is Accepted then the specified amount of new tokens will be added to the Public Account
    // For implementation see VillageCoin.enactProposal
    function proposeCreateMoney(Proposals storage self, uint amount, string supportingEvidence, bool isPartOfPackage) public returns(uint) {

        return createProposal(self, ProposalType.CreateMoney, supportingEvidence, "", "", amount, 0x0, isPartOfPackage);
    }

    // Create a new Proposal of type DestroyMoney
    // If the Proposal is Accepted then the specified amount of tokens from Public Account will be burned, or the full public account balance, whichever is smaller
    // For implementation see VillageCoin.enactProposal
    function proposeDestroyMoney(Proposals storage self, uint amount, string supportingEvidence, bool isPartOfPackage) public returns(uint) {

        return createProposal(self, ProposalType.DestroyMoney, supportingEvidence, "", "", amount, 0x0, isPartOfPackage);
    }

    // Create a new Proposal of type PayCitizen
    // If the Proposal is Accepted then the specified amount of tokens will bre transferred from the Public Account to the specified Citizen
    // For implementation see VillageCoin.enactProposal
    function proposePayCitizen(Proposals storage self, address citizen, uint amount, string supportingEvidence, bool isPartOfPackage) public returns(uint) {
        return createProposal(self, ProposalType.PayCitizen, supportingEvidence, "", "", amount, citizen, isPartOfPackage);
    }

    // Create a new Proposal of type FineCitizen
    // If the Proposal is Accepted then the specified amount of tokens will bre transferred from the specified Citizen to the Public Account
    // For implementation see VillageCoin.enactProposal
    function proposeFineCitizen(Proposals storage self, address citizen, uint amount, string supportingEvidence, bool isPartOfPackage) public returns(uint) {
        return createProposal(self, ProposalType.FineCitizen, supportingEvidence, "", "", amount, citizen, isPartOfPackage);
    }

    function createProposal(Proposals storage self, ProposalType typ, string supportingEvidenceUrl, string stringParam1, string stringParam2, uint numberParam1, address addressParam1, bool isPartOfPackage) private returns(uint) {
                
        var proposalId = self.nextProposalId;
        self.nextProposalId = self.nextProposalId.plus(1);

        assert(!self.proposals[proposalId].isExistent);

        self.proposals[proposalId].isExistent = true;
        self.proposals[proposalId].proposer = msg.sender;
        self.proposals[proposalId].typ = typ;
        self.proposals[proposalId].supportingEvidenceUrl = supportingEvidenceUrl;
        self.proposals[proposalId].stringParam1 = stringParam1;
        self.proposals[proposalId].stringParam2 = stringParam2;
        self.proposals[proposalId].numberParam1 = numberParam1;
        self.proposals[proposalId].addressParam1 = addressParam1; 
        self.proposals[proposalId].isPartOfPackage = isPartOfPackage;                  

        OnProposalCreated(proposalId);           

        return proposalId;
    }

    function getItemsOfPackage(Proposals storage self, uint proposalId) public constant returns(uint[]) {
        require(self.proposals[proposalId].isExistent);
        require(self.proposals[proposalId].typ == ProposalType.Package);

        return self.proposals[proposalId].packageParts;
    }
}