pragma solidity ^0.4.9;

import "./SafeMathLib.sol";
import "./Storage.sol";
import "./ParameterLib.sol";
import "./TokenLib.sol";


// A proposal is a suggestion to make specific change or set of changes to the state of the contract
// There are several types of proposal that make different types of changes
// The Proposal object can repreesent any of the types of proposal
// Proposals is a collection of Proposal objects
// Items can be added to the Proposals collection using the proposeXXX functions
// All data is stored in a Storage
// The changes described by a proposal may be enacted using the enactProposal function
library ProposalLib {

    using SafeMathLib for uint;

    event OnProposalCreated(uint proposalId);

    uint constant public E_PROPOSAL_TYPE_SET_PARAMETER = 0;
    uint constant public E_PROPOSAL_TYPE_CREATE_MONEY = 1;
    uint constant public E_PROPOSAL_TYPE_DESTROY_MONEY = 2;
    uint constant public E_PROPOSAL_TYPE_PAY_CITIZEN = 3;
    uint constant public E_PROPOSAL_TYPE_FINE_CITIZEN = 4;
    uint constant public E_PROPOSAL_TYPE_PACKAGE = 5;

    bytes32 constant public F_NEXT_ID = sha3("F_PROPOSAL_NEXT_ID");

    bytes32 constant public F_PROPOSER = sha3("F_PROPOSAL_PROPOSER");
    bytes32 constant public F_TYPE = sha3("F_PROPOSAL_TYPE");
    bytes32 constant public F_IS_EXISTENT = sha3("F_PROPOSAL_IS_EXISTENT");
    bytes32 constant public F_SUPPORTING_EVIDENCE_URL = sha3("F_PROPOSAL_SUPPORTING_EVIDENCE_URL");
    bytes32 constant public F_STRING_PARAM_1 = sha3("F_PROPOSAL_STRING_PARAM_1");
    bytes32 constant public F_STRING_PARAM_2 = sha3("F_PROPOSAL_STRING_PARAM_2");
    bytes32 constant public F_NUMBER_PARAM_1 = sha3("F_PROPOSAL_NUMBER_PARAM_1");
    bytes32 constant public F_ADDRESS_PARAM_1 = sha3("F_PROPOSAL_ADDRESS_PARAM_1");
    bytes32 constant public F_IS_PART_OF_PACKAGE = sha3("F_PROPOSAL_IS_PART_OF_PACKAGE");
    bytes32 constant public F_IS_ASSIGNED_TO_PACKAGE = sha3("F_PROPOSAL_IS_ASSIGNED_TO_PACKAGE");
    bytes32 constant public F_NUM_PACKAGE_PARTS = sha3("F_PROPOSAL_NUM_PACKAGE_PARTS");
    bytes32 constant public F_PACKAGE_PART = sha3("F_PROPOSAL_PACKAGE_PART");

    // create a new Proposal of type Package
    // a Package Proposal is a Proposal that contains a number of other Proposals called 'Parts'
    // If a Package Proposal is Accepted then all of its Parts are enacted
    // Parts cannot themselves be Package Proposals
    // Parts must be marked as isPartOfPacakge
    // Parts must NOT be maked as isAssignedToPackage
    // This function sets isAssignedToPackage to true for all the specified parts
    function proposePackage(Storage self, uint[] partIds, bytes32 supportingEvidence) public returns(uint) {

        require(partIds.length <= 64);

        var proposalId = createProposal(self, E_PROPOSAL_TYPE_PACKAGE, supportingEvidence, "", "", 0, 0x0, false);
        
        self.setUInt(F_NUM_PACKAGE_PARTS, proposalId, partIds.length);

        for (uint i = 0; i < partIds.length; i++) {
            var partId = partIds[i];
            
            require(self.getBool(F_IS_EXISTENT, partId));
            require(self.getBool(F_IS_PART_OF_PACKAGE, partId));
            require(!self.getBool(F_IS_ASSIGNED_TO_PACKAGE, partId));
            require(self.getUInt(F_TYPE, partId) != E_PROPOSAL_TYPE_PACKAGE);
            require(self.getAddress(F_PROPOSER, partId) == msg.sender);

            var packagePartKey = keccak256(F_PACKAGE_PART, i);
            self.setUInt(packagePartKey, proposalId, partId);
            self.setBool(F_IS_ASSIGNED_TO_PACKAGE, partId, true);
        }

        return proposalId;
    }

    // Create a new Proposal of type SetParameter
    // If a SetParameter Proposal is Accepted then the named Parameter will be set to the specified value
    // Note: this function does not check the validity of the input parameters so you need to do that elsewhere
    function proposeSetParameter (
        Storage self, 
        bytes32 parameterName,
        bytes32 stringValue,
        uint numberValue,
        bytes32 supportingEvidence,
        bool isPartOfPackage
    ) public returns(uint)
    {
        return createProposal(self, E_PROPOSAL_TYPE_SET_PARAMETER, supportingEvidence, parameterName, stringValue, numberValue, 0x0, isPartOfPackage);
    }

    // Create a new Proposal of type CreateMoney
    // If the Proposal is Accepted then the specified amount of new tokens will be added to the Public Account
    // For implementation see VillageCoin.enactProposal
    function proposeCreateMoney(Storage self, uint amount, bytes32 supportingEvidence, bool isPartOfPackage) public returns(uint) {

        return createProposal(self, E_PROPOSAL_TYPE_CREATE_MONEY, supportingEvidence, 0x0, 0x0, amount, 0x0, isPartOfPackage);
    }

    // Create a new Proposal of type DestroyMoney
    // If the Proposal is Accepted then the specified amount of tokens from Public Account will be burned, or the full public account balance, whichever is smaller
    // For implementation see VillageCoin.enactProposal
    function proposeDestroyMoney(Storage self, uint amount, bytes32 supportingEvidence, bool isPartOfPackage) public returns(uint) {

        return createProposal(self, E_PROPOSAL_TYPE_DESTROY_MONEY, supportingEvidence, 0x0, 0x0, amount, 0x0, isPartOfPackage);
    }

    // Create a new Proposal of type PayCitizen
    // If the Proposal is Accepted then the specified amount of tokens will bre transferred from the Public Account to the specified Citizen
    // For implementation see VillageCoin.enactProposal
    function proposePayCitizen(Storage self, address citizen, uint amount, bytes32 supportingEvidence, bool isPartOfPackage) public returns(uint) {
        return createProposal(self, E_PROPOSAL_TYPE_PAY_CITIZEN, supportingEvidence, 0x0, 0x0, amount, citizen, isPartOfPackage);
    }

    // Create a new Proposal of type FineCitizen
    // If the Proposal is Accepted then the specified amount of tokens will bre transferred from the specified Citizen to the Public Account
    // For implementation see VillageCoin.enactProposal
    function proposeFineCitizen(Storage self, address citizen, uint amount, bytes32 supportingEvidence, bool isPartOfPackage) public returns(uint) {
        return createProposal(self, E_PROPOSAL_TYPE_FINE_CITIZEN, supportingEvidence, 0x0, 0x0, amount, citizen, isPartOfPackage);
    }

    function createProposal(
        Storage self, 
        uint typ, 
        bytes32 supportingEvidenceUrl, 
        bytes32 stringParam1, 
        bytes32 stringParam2, 
        uint numberParam1, 
        address addressParam1, 
        bool isPartOfPackage) private returns(uint) 
        {
                
        var proposalId = self.getUInt(F_NEXT_ID);
        if (proposalId == 0) {
            proposalId = 1; // 0 is not a valid ID
        }
        self.setUInt(F_NEXT_ID, proposalId.plus(1));

        assert(!self.getBool(F_IS_EXISTENT, proposalId));

        self.setBool(F_IS_EXISTENT, proposalId, true);
        self.setAddress(F_PROPOSER, proposalId, msg.sender);
        self.setUInt(F_TYPE, proposalId, typ);

        if (supportingEvidenceUrl != 0x0) {
            self.setBytes32(F_SUPPORTING_EVIDENCE_URL, proposalId, supportingEvidenceUrl);
        }
        if (stringParam1 != 0x0) {
            self.setBytes32(F_STRING_PARAM_1, proposalId, stringParam1);
        }
        if (stringParam2 != 0x0) {
            self.setBytes32(F_STRING_PARAM_2, proposalId, stringParam2);
        }
        if (numberParam1 != 0) {
            self.setUInt(F_NUMBER_PARAM_1, proposalId, numberParam1);
        }
        if (addressParam1 != 0x0) {
            self.setAddress(F_ADDRESS_PARAM_1, proposalId, addressParam1);
        }
        if (isPartOfPackage) {
            self.setBool(F_IS_PART_OF_PACKAGE, proposalId, isPartOfPackage);
        }

        OnProposalCreated(proposalId);           

        return proposalId;
    }

    function getIsPartOfPackage(Storage self, uint proposalId) public constant returns(bool) {
        require(self.getBool(F_IS_EXISTENT, proposalId));
        return self.getBool(F_IS_PART_OF_PACKAGE, proposalId);
    }

    function getNextId(Storage self) public constant returns(uint) {
        return self.getUInt(F_NEXT_ID);
    }

    function getProposalA(Storage self, uint proposalId) public constant returns(
        uint typ, 
        address proposer, 
        bool isExistent,
        bytes32 stringParam1,
        bytes32 stringParam2) 
        {
            typ = self.getUInt(F_TYPE, proposalId);
            proposer = self.getAddress(F_PROPOSER, proposalId);
            isExistent = self.getBool(F_IS_EXISTENT, proposalId);
            stringParam1 = self.getBytes32(F_STRING_PARAM_1, proposalId);
            stringParam2 = self.getBytes32(F_STRING_PARAM_2, proposalId);

            return;
    }

    function getProposalB(Storage self, uint proposalId) public constant returns(      
        uint numberParam1,              
        address addressParam1,                    
        bytes32 supportingEvidenceUrl,
        bool isPartOfPackage,
        bool isAssignedToPackage) 
        {
            numberParam1 = self.getUInt(F_NUMBER_PARAM_1, proposalId);
            addressParam1 = self.getAddress(F_ADDRESS_PARAM_1, proposalId);
            supportingEvidenceUrl = self.getBytes32(F_SUPPORTING_EVIDENCE_URL, proposalId);
            isPartOfPackage = self.getBool(F_IS_PART_OF_PACKAGE, proposalId);
            isAssignedToPackage = self.getBool(F_IS_ASSIGNED_TO_PACKAGE, proposalId);

            return;
    }

    function getPackagePartCount(Storage self, uint proposalId) public constant returns(uint) {
        require(self.getBool(F_IS_EXISTENT, proposalId));
        require(self.getUInt(F_TYPE, proposalId) == E_PROPOSAL_TYPE_PACKAGE);

        return self.getUInt(F_NUM_PACKAGE_PARTS, proposalId);
    }

    function getPackagePart(Storage self, uint proposalId, uint i) public constant returns(uint) {
        require(self.getBool(F_IS_EXISTENT, proposalId));
        require(self.getUInt(F_TYPE, proposalId) == E_PROPOSAL_TYPE_PACKAGE);
        require(self.getUInt(F_NUM_PACKAGE_PARTS, proposalId) > i);

        var packagePartKey = keccak256(F_PACKAGE_PART, i);
        return self.getUInt(packagePartKey, proposalId);
    }

    function enactProposal(Storage self, uint proposalId) public {

        if (proposalId == 0) {
            return;
        }

        var typ = self.getUInt(F_TYPE, proposalId);
        var isExistent = self.getBool(F_IS_EXISTENT, proposalId);
        var stringParam1 = self.getBytes32(F_STRING_PARAM_1, proposalId);
        var stringParam2 = self.getBytes32(F_STRING_PARAM_2, proposalId);
        var numberParam1 = self.getUInt(F_NUMBER_PARAM_1, proposalId);
        var addressParam1 = self.getAddress(F_ADDRESS_PARAM_1, proposalId);

        assert(isExistent);

        if (typ == E_PROPOSAL_TYPE_SET_PARAMETER) {
                ParameterLib.set(self, stringParam1, stringParam2, numberParam1);
            } else if (typ == E_PROPOSAL_TYPE_CREATE_MONEY) {
                TokenLib.createMoney(self, numberParam1);
            } else if (typ == E_PROPOSAL_TYPE_DESTROY_MONEY) {
                TokenLib.destroyMoney(self, numberParam1);        
            } else if (typ == E_PROPOSAL_TYPE_PAY_CITIZEN) {
                TokenLib.transferAsMuchAsPossibleOf(self, TokenLib.getPublicAccount(), addressParam1, numberParam1);
            } else if (typ == E_PROPOSAL_TYPE_FINE_CITIZEN) {
                TokenLib.transferAsMuchAsPossibleOf(self, addressParam1, TokenLib.getPublicAccount(), numberParam1);
            } else if (typ == E_PROPOSAL_TYPE_PACKAGE) {
                var partCount = getPackagePartCount(self, proposalId);
                for (uint i = 0; i < partCount; i++) {
                    var partId = getPackagePart(self, proposalId, i);
                    enactProposal(self, partId);
                }
            } else {
                revert();
            }
    }
}