pragma solidity ^0.4.9;

import "./SafeMathLib.sol";

library ProposalLib {

    using SafeMathLib for uint;
    using ProposalLib for ProposalSet;

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
        ProposalType typ;
        address proposer;        
        bool isExistent;
        //uint expiryTime;
        string stringParam1;
        string stringParam2;        
        uint numberParam1;                
        address addressParam1;                    
        string supportingEvidenceUrl;
        bool isPartOfPackage;
        bool isAssignedToPackage;
        uint[] packageParts;
    }

    struct ProposalSet {
        uint nextProposalId;
        mapping(uint=>Proposal) proposals;
    }

    function proposePackage(ProposalSet storage self, uint[] partIds, string supportingEvidence) public returns(uint){

        require(partIds.length <= 32);

        var proposalId = createProposal(self, ProposalType.Package, supportingEvidence, "", "", 0, 0x0, false);
        
        for (uint i = 0; i < partIds.length; i++) {
            var partId = partIds[i];
            var part = self.proposals[partId];
            require(part.isExistent);
            require(part.isPartOfPackage);
            require(!part.isAssignedToPackage);
            require(part.typ != ProposalType.Package);
            require(part.proposer == msg.sender); // not really neccesary

            self.proposals[proposalId].packageParts.push(partId);
            self.proposals[partId].isAssignedToPackage = true;
        }

        return proposalId;
    }

    function proposeSetParameter (
        ProposalSet storage self, 
        string parameterName,
        string stringValue,
        uint numberValue,
        string supportingEvidence,
        bool isPartOfPackage
    ) public returns(uint)
    {
        return createProposal(self, ProposalType.SetParameter, supportingEvidence, parameterName, stringValue, numberValue, 0x0, isPartOfPackage);
    }

    function proposeCreateMoney(ProposalSet storage self, uint amount, string supportingEvidence, bool isPartOfPackage) public returns(uint) {

        return createProposal(self, ProposalType.CreateMoney, supportingEvidence, "", "", amount, 0x0, isPartOfPackage);
    }

    function proposeDestroyMoney(ProposalSet storage self, uint amount, string supportingEvidence, bool isPartOfPackage) public returns(uint) {

        return createProposal(self, ProposalType.DestroyMoney, supportingEvidence, "", "", amount, 0x0, isPartOfPackage);
    }

    function proposePayCitizen(ProposalSet storage self, address citizen, uint amount, string supportingEvidence, bool isPartOfPackage) public returns(uint) {
        return createProposal(self, ProposalType.PayCitizen, supportingEvidence, "", "", amount, citizen, isPartOfPackage);
    }

    function proposeFineCitizen(ProposalSet storage self, address citizen, uint amount, string supportingEvidence, bool isPartOfPackage) public returns(uint) {
        return createProposal(self, ProposalType.FineCitizen, supportingEvidence, "", "", amount, citizen, isPartOfPackage);
    }

    function createProposal(ProposalSet storage self, ProposalType typ, string supportingEvidenceUrl, string stringParam1, string stringParam2, uint numberParam1, address addressParam1, bool isPartOfPackage) private returns(uint) {
                
        var proposalId = self.nextProposalId;
        self.nextProposalId = self.nextProposalId.plus(1);

        assert(!self.proposals[proposalId].isExistent);

        // if (!isPartOfPackage) {
        //     uint tax = calculateProposalTax(msg.sender);
        //     require(balanceOf(msg.sender) >= tax);
        //     transferInternal(msg.sender, PUBLIC_ACCOUNT, tax);

        //     _referendums[proposalId].init();
        // }

        self.proposals[proposalId].isExistent = true;
        self.proposals[proposalId].proposer = msg.sender;
        self.proposals[proposalId].typ = typ;
        //self.proposals[proposalId].expiryTime = now.plus(getNumberParameter("proposalTimeLimitDays").times(1 days));
        self.proposals[proposalId].supportingEvidenceUrl = supportingEvidenceUrl;
        self.proposals[proposalId].stringParam1 = stringParam1;
        self.proposals[proposalId].stringParam2 = stringParam2;
        self.proposals[proposalId].numberParam1 = numberParam1;
        self.proposals[proposalId].addressParam1 = addressParam1; 
        self.proposals[proposalId].isPartOfPackage = isPartOfPackage; 

        // if (isPartOfPackage) {
        //     self.proposalstatus[proposalId].decision = ProposalDecision.PackageUnassigned;
        // }                     

        OnProposalCreated(proposalId);           

        return proposalId;
    }

    function getItemsOfPackage(ProposalSet storage self, uint proposalId) public constant returns(uint[]) {
        require(self.proposals[proposalId].isExistent);
        require(self.proposals[proposalId].typ == ProposalType.Package);

        return self.proposals[proposalId].packageParts;
    }
}