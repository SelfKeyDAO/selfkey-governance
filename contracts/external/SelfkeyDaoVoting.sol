// SPDX-License-Identifier: proprietary
pragma solidity 0.8.19;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./ISelfkeyIdAuthorization.sol";
import "./ISelfkeyDaoVoting.sol";

struct PoiTimeLock {
    uint256 timestamp;
    uint amount;
}

contract SelfkeyDaoVoting is Initializable, OwnableUpgradeable, ISelfkeyDaoVoting {

    address public authorizedSigner;
    ISelfkeyIdAuthorization public authorizationContract;

    // Mapping to store proposals by ID
    mapping(uint256 => Proposal) public proposals;
    // Variable to store the number of proposals
    uint256 public numProposals;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _authorizationContract) public initializer {
        __Ownable_init();

        authorizationContract = ISelfkeyIdAuthorization(_authorizationContract);
    }

    // Modifier to check if the sender has not voted yet for the given proposal
    modifier hasNotVoted(uint256 proposalId) {
        require(!proposals[proposalId].hasVoted[msg.sender]);
        _;
    }

    function setAuthorizationContractAddress(address _newAuthorizationContractAddress) public onlyOwner {
        authorizationContract = ISelfkeyIdAuthorization(_newAuthorizationContractAddress);
        emit AuthorizationContractAddressChanged(_newAuthorizationContractAddress);
    }

    // Function to create a new proposal
    function createProposal(string memory _title, bool _active) external onlyOwner {
        numProposals++;
        proposals[numProposals].title = _title;
        proposals[numProposals].active = _active;

        emit ProposalCreated(numProposals, _title, _active);
    }

    function updateProposal(uint256 _proposalId, string memory _title, bool _active) external onlyOwner {
        require(bytes(proposals[_proposalId].title).length > 0, "Proposal ID does not exist");

        proposals[_proposalId].title = _title;
        proposals[_proposalId].active = _active;

        emit ProposalChanged(_proposalId, _title, _active);
    }

    // Function to cast a vote for a particular proposal
    function vote(address _voter, uint256 _votes, bytes32 _param, uint _timestamp, address _signer, bytes memory signature) external {

        uint256 proposalId = uint256(_param);

        // Verify that the proposal exists
        require(bytes(proposals[proposalId].title).length > 0, "Proposal does not exist");

        // Verify that the proposal is active
        require(proposals[proposalId].active, "Proposal is not active");

        // Verify that the sender has not voted yet for the given proposal
        require(!hasUserVoted(proposalId, _voter), "Already voted for this proposal");

        // Verify payload
        authorizationContract.authorize(address(this), _voter, _votes, 'gov:proposal:vote', _param, _timestamp, _signer, signature);

        // Mark the sender as having voted for the given proposal
        proposals[proposalId].hasVoted[_voter] = true;

        // Increment the vote count for the chosen option of the given proposal
        proposals[proposalId].voteCount = proposals[proposalId].voteCount + _votes;

        // Emit the VoteCast event
        emit VoteCast(proposalId, _voter, _votes);
    }

    // Function to get the vote count for a specific option of a proposal
    function getVoteCount(uint256 _proposalId) external view returns (uint256) {
        return proposals[_proposalId].voteCount;
    }

    // Function to check if a user has voted for a specific proposal
    function hasUserVoted(uint256 _proposalId, address _voter) public view returns (bool) {
        return proposals[_proposalId].hasVoted[_voter];
    }
}
