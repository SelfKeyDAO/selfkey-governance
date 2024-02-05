// SPDX-License-Identifier: proprietary
pragma solidity 0.8.19;

interface ISelfkeyDaoVoting {

    // Struct to represent a proposal
    struct Proposal {
        string title;
        mapping(address => bool) hasVoted;
        uint256 voteCount;
        bool active;
    }

    event AuthorizationContractAddressChanged(address indexed _address);
    event ProposalCreated(uint256 proposalId, string title, bool active);
    event ProposalChanged(uint256 proposalId, string title, bool active);
    event VoteCast(uint256 indexed proposalId, address indexed voter, uint256 votes);

    function initialize(address _authorizationContract) external;
    function setAuthorizationContractAddress(address _newAuthorizationContractAddress) external;
    function createProposal(string memory _title, bool _active) external;
    function updateProposal(uint256 _proposalId, string memory _title, bool _active) external;
    function vote(address _voter, uint256 _votes, bytes32 _param, uint _timestamp, address _signer, bytes memory signature) external;
    function getVoteCount(uint256 _proposalId) external view returns (uint256);
    function hasUserVoted(uint256 _proposalId, address _voter) external view returns (bool);
    function numProposals() external view returns (uint256);
}
