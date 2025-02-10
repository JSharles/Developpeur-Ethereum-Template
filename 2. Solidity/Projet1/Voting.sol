// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;
import "@openzeppelin/contracts/access/Ownable.sol";

contract Voting is Ownable {
    
    enum WorkflowStatus {
        registerVoters, 
        ProposalsRegistrationStarted, 
        ProposalsRegistrationEnded, 
        VotingSessionStarted,
        VotingSessionEnded,
        VotesTallied
        }

    struct Voter {
        bool isRegistered;
        bool hasVoted;
        uint votedProposalId;
    }
    
    struct Proposal {
        string description;
        uint voteCount;
    }

    mapping(address => Voter) public _voters;

    mapping(uint => address) public _proposalOwner;

    Proposal[] public _proposals;
         
    uint winningProposalId;
    uint[] public winningProposals;
    
    WorkflowStatus public ballotStatus;

    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);
    event VoterRegistered(address voterAddress);
    event ProposalRegistered(uint proposalId);
    event ProposalDuplicate(address voter, string message);
    event Voted (address voter, uint proposalId);
    event VoterAlreadyRegistered(address voter);
    
    constructor() Ownable(msg.sender) { 
        _voters[msg.sender] = Voter(true, false, 0);
        ballotStatus = WorkflowStatus.registerVoters;
    }

    modifier checkStatus(WorkflowStatus current, WorkflowStatus shouldBe) {
        require(current == shouldBe, "This action is not available at this stage of the ballot");
        _;
    }

    modifier isVoterRegistered(address voterAddress) {
        require(_voters[voterAddress].isRegistered, "Voter is not registered");
        _;
    }

    function getBallotStatus() external view returns (WorkflowStatus){
        return ballotStatus;
    }

    function startProposalsRegistration() external onlyOwner {
        ballotStatus = WorkflowStatus.ProposalsRegistrationStarted;
        emit WorkflowStatusChange(WorkflowStatus.registerVoters, ballotStatus);
    }

    function endProposalsRegistration() external onlyOwner {
        ballotStatus = WorkflowStatus.ProposalsRegistrationEnded;
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationStarted, ballotStatus);
    }

    function startVotingSession() external onlyOwner {
        ballotStatus = WorkflowStatus.VotingSessionStarted;
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationEnded,ballotStatus);
    }

    function endVotingSession() external onlyOwner {
        ballotStatus = WorkflowStatus.VotingSessionEnded;
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionStarted,ballotStatus);
    }

    function tallyVotes() external onlyOwner {
        ballotStatus = WorkflowStatus.VotesTallied;
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionEnded,ballotStatus);
    }

    function register(address[] calldata voters) external onlyOwner checkStatus(ballotStatus, WorkflowStatus.registerVoters) {
        
        require(voters.length > 0, "No voters provided");
        
        for (uint i; i < voters.length; i++) {
            if (_voters[voters[i]].isRegistered) {
                emit VoterAlreadyRegistered(voters[i]);
                continue;
            }
            
            _voters[voters[i]] = Voter(true, false, 0);
            emit VoterRegistered(voters[i]);
        }
    }

    // We assume that a voter is allowed to register multiple proposals
    function registerProposal(address voterAddr, string calldata voterProposal) 
        external onlyOwner 
        checkStatus(ballotStatus, WorkflowStatus.ProposalsRegistrationStarted) 
        isVoterRegistered(voterAddr) 
    {
        _proposals.push(Proposal(voterProposal, 0));
        _proposalOwner[_proposals.length - 1] = voterAddr;
        emit ProposalRegistered(_proposals.length - 1);
    }

    // We could also allow voters to view proposals before proposal's registration ends
    function getProposals() external view checkStatus(ballotStatus, WorkflowStatus.VotingSessionStarted) isVoterRegistered(msg.sender) returns (Proposal[] memory) {
       return _proposals;
    }

    function vote(uint proposalId) external checkStatus(ballotStatus, WorkflowStatus.VotingSessionStarted) isVoterRegistered(msg.sender) {

        require(!_voters[msg.sender].hasVoted, "Voter is not allowed to vote twice"); 

        _voters[msg.sender].hasVoted = true;
        _voters[msg.sender].votedProposalId = proposalId;
        _proposals[proposalId].voteCount += 1;
        emit Voted(msg.sender, proposalId);
    }

    function countVotes() external checkStatus(ballotStatus, WorkflowStatus.VotingSessionEnded) onlyOwner {
        uint highestCount;
        delete winningProposals; 

        for (uint i = 0; i < _proposals.length; i++) {
            if (_proposals[i].voteCount > highestCount) {
                highestCount = _proposals[i].voteCount;
                delete winningProposals; 
                winningProposals.push(i);
            } else if (_proposals[i].voteCount == highestCount) {
                winningProposals.push(i);
            }
        }

        if(winningProposals.length == 1) {
            winningProposalId = winningProposals[0];
        }
    }
    
    function getWinner() external view checkStatus(ballotStatus, WorkflowStatus.VotesTallied) returns (address) {
        require(winningProposals.length == 1, "The vote requires another round as some proposals have ended in a tie");
        return _proposalOwner[winningProposalId];
    }
        
    function getWinningProposal() external view checkStatus(ballotStatus, WorkflowStatus.VotesTallied) returns (Proposal memory) {
        require(winningProposals.length == 1, "The vote requires another round as some proposals have ended in a tie");
        return _proposals[winningProposalId];
    }
}