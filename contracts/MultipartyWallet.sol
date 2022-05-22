//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.11;

import "hardhat/console.sol";

/**
  @notice multiparty wallet where contract stores funds
  @dev tried with minimal storage just to meet requirements
 */
contract MultipartyWallet {
    address public administrator;
    mapping(address => uint256) public ownerNonce;
    // sender => nonce => tx details
    mapping(address => mapping(uint256 => Transaction)) public proposals;
    uint256 public voteThreshold;

    struct Transaction {
        address recipient;
        uint256 amount;
        uint64 votes;
        ProposalStatus status;
    }

    enum ProposalStatus {
        NonExisting,
        Initiated,
        Passed,
        Executed
    }

    event ProposalEvent(
        address sender,
        uint256 nonce,
        address recipient,
        uint256 amount,
        ProposalStatus status
    );

    constructor(address _administrator, uint256 _voteThreshold) {
        administrator = _administrator;
        voteThreshold = _voteThreshold;
    }

    modifier onlyAdmin() {
        require(msg.sender == administrator, "sender is not administrator");
        _;
    }

    modifier isOwner() {
        require(ownerNonce[msg.sender] > 0, "sender is not owner");
        _;
    }

    // to send ETH to contract
    receive() external payable {}

    function changeAdmin(address newAdmin) external onlyAdmin {
        administrator = newAdmin;
    }

    function changeVoteThreshold(uint256 newThreshold) external onlyAdmin {
        voteThreshold = newThreshold;
    }

    function createOwner(address owner) external onlyAdmin {
        ownerNonce[owner] = 1;
    }

    function removeOwner(address owner) external onlyAdmin {
        ownerNonce[owner] = 0;
    }

    /**
      @notice to create txn by owner to send ETH to recipient
     */
    function createTransaction(address recipient, uint256 amount)
        external
        isOwner
    {
        ownerNonce[msg.sender] += 1;
        uint256 nonce = ownerNonce[msg.sender];
        proposals[msg.sender][nonce] = Transaction(
            recipient,
            amount,
            0,
            ProposalStatus.Initiated
        );
        emit ProposalEvent(
            msg.sender,
            nonce,
            recipient,
            amount,
            ProposalStatus.Initiated
        );
    }

    /**
      @notice to vote on txn created by an owner
      @dev cannot be called by txn creator
      @dev can only be called by owner addresses
      @dev checked min votes required and passes the proposal
     */
    function voteProposal(
        address sender,
        uint256 nonce,
        address recipient,
        uint256 amount
    ) external isOwner {
        Transaction memory txn = proposals[sender][nonce];
        require(
            txn.status == ProposalStatus.Initiated,
            "proposal doesn't exist"
        );
        require(msg.sender != sender, "proposal creator cannot vote");
        require(
            txn.recipient == recipient && txn.amount == amount,
            "wrong txn data"
        );

        txn.votes += 1;
        if (txn.votes >= voteThreshold) {
            txn.status = ProposalStatus.Passed;
        }

        proposals[sender][nonce] = txn;

        emit ProposalEvent(sender, nonce, recipient, amount, txn.status);
    }

    /**
      @notice to execute proposal i.e. transfer ETH to recipient
      @dev can only be called by txn creator
     */
    function executeProposal(
        uint256 nonce,
        address payable recipient,
        uint256 amount
    ) external {
        Transaction memory txn = proposals[msg.sender][nonce];
        require(txn.status == ProposalStatus.Passed, "proposal not passed");
        require(
            txn.recipient == recipient && txn.amount == amount,
            "wrong txn data"
        );
        require(address(this).balance >= amount, "low balance");

        txn.status = ProposalStatus.Executed;
        proposals[msg.sender][nonce] = txn;
        recipient.transfer(amount);

        emit ProposalEvent(msg.sender, nonce, recipient, amount, txn.status);
    }
}
