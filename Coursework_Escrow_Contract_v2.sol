/*
Key Features in the Completed Contract

Multi-Signature Escrow Contracts:
Multiple arbiters can participate in resolving disputes.
A majority of arbiters must approve the resolution for it to take effect.
approveResolution function handles arbiter approvals.

Dynamic Collateral Requirements:
Seller collateral is dynamically calculated based on a percentage of the transaction amount (collateralPercentage).

Flexible Fee Structures:
Fees are calculated as a percentage of the escrow amount (feePercentage).
The contract collects fees upon successful completion or dispute resolution.

Dispute Resolution Mechanism:
A dispute is resolved when more than half of the arbiters approve a decision (approvalCount > arbiters.length / 2).

State Tracking:
The contract maintains a clear state machine (EscrowState) for managing the workflow.
*/


// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


contract FreelancerEscrow {
    address public client;
    address payable freelancer;
    address[] public arbitrators;
    uint256 public totalPayment;
    uint256 public milestoneAmount;
    string public projectDescription;

    //Needed?
    uint256 public currentMilestone;
    uint256 public deliveryDeadline;
    bool public depositMade = false;
    // uint256 public disputeResolutionDeadline;
    //bool public isDisputeRaised;

    uint256 public feePercentage = 20; // Fee percentage in basis points (e.g., 200 = 2%)

    enum EscrowState { AWAITING_DEPOSIT, AWAITING_DELIVERY, COMPLETE, CONFIRMED, DISPUTE }
    EscrowState public state = EscrowState.AWAITING_PAYMENT;

    mapping(uint256 => uint256) public milestonePayments;
    mapping(uint256 => string) public milestoneDescriptions;
    mapping(uint256 => bool) public hasApproved;
    // mapping(address => bool) public hasCompleted;

    uint256 public approvalCount;

    /*
    event DeliveryConfirmed(address indexed buyer, address indexed seller);
    event DisputeRaised(address indexed buyer);
    event DisputeResolved(address indexed arbiter, bool refundToBuyer);
    event CollateralForfeited(address indexed party, uint256 amount);
    event FeeCollected(address indexed collector, uint256 amount);
    */

   // event FreelancerApplied(address indexed freelancer, uint256 proposedAmount, string pitch);
   event DepositMade(address indexed buyer, uint256 amount);
   event DeliverableCompleted(address indexed buyer, address indexed seller);
   event DeliveryConfirmed(address indexed buyer, address indexed seller);

    constructor(
        address _client,
        address _freelancer,
        uint256 _totalPayment,
        string _projectDescription,
        uint256 _deliveryDeadline
    ) {
        require(_totalPayment > 0, "Amount must be greater than zero");

        client = _client;
        freelancer = _freelancer;
        totalPayment = _totalPayment;
        deliveryDeadline = block.timestamp + _deliveryDeadline;
        projectDescription = _projectDescription;

        // disputeResolutionDeadline = block.timestamp + _disputeResolutionDeadline;
        // collateralPercentage = _collateralPercentage;
        // Require seller to stake collateral as a safeguard
        // uint256 sellerCollateral = (_amount * _collateralPercentage) / 10000;
        // require(token.transferFrom(seller, address(this), sellerCollateral), "Seller collateral transfer failed");
    }

    function makeDeposit() external payable {
        require(msg.sender.balance >= totalPayment, "Insufficient balance for deposit");
        require(msg.sender == client, "Only client can perform this action");
        require(state == EscrowState.AWAITING_DEPOSIT, "Invalid state for this action");

        // Transfer funds to the contract
        msg.sender.transfer(totalPayment);

        state = EscrowState.AWAITING_DELIVERY;
        emit DepositMade(client, freelancer, totalPayment);
    }

    function finishedDeliverable(uint256 _milestone, string _description) external {
        require(msg.sender == freelancer, "Only freelancer can perform this action");
        require(state == EscrowState.AWAITING_DELIVERY, "Invalid state for this action");

        state = EscrowState.COMPLETE;
            
        emit DeliverableCompleted(client, freelancer);
    }

    function confirmDelivery() external {
        require(msg.sender == client, "Only client can perform this action");
        require(state == EscrowState.COMPLETE, "Invalid state for this action");

        // Transfer funds to the freelancer
        freelancer.transfer(totalPayment);

        state = EscrowState.CONFIRMED;
        emit DeliveryConfirmed(client, freelancer);
    }



    /*
    function freelancerApply(uint256 proposedAmount, string pitch) public {
        require(state == EscrowState.AWAITING_PAYMENT, "Invalid state for this action");
        address potential_freelancer = msg.sender;

        emit FreelancerApplied(potential_freelancer, proposedAmount, pitch);
    }

    function clientApproveFreelancer(address _freelancer) public {
        require(msg.sender == client, "Only client can perform this action");
        require(state == EscrowState.AWAITING_PAYMENT, "Invalid state for this action");

        freelancer = _freelancer;

        state = EscrowState.AWAITING_DELIVERY;
    }
    */

   /*
    function raiseDispute() external onlyBuyer inState(EscrowState.AWAITING_DELIVERY) withinDeadline(deliveryDeadline) {
        state = EscrowState.DISPUTE;
        isDisputeRaised = true;
        emit DisputeRaised(buyer);
    }

    function approveResolution(bool refundToBuyer) external onlyArbiter inState(EscrowState.DISPUTE) {
        require(!hasApproved[msg.sender], "Arbiter has already approved");
        hasApproved[msg.sender] = true;
        approvalCount++;

        if (approvalCount > arbiters.length / 2) {
            uint256 sellerCollateral = (escrowAmount * collateralPercentage) / 10000;
            uint256 fee = (escrowAmount * feePercentage) / 10000;
            uint256 amountAfterFee = escrowAmount - fee;

            if (refundToBuyer) {
                require(token.transfer(buyer, amountAfterFee), "Refund to buyer failed");
                require(token.transfer(buyer, sellerCollateral), "Collateral refund to buyer failed");
                emit CollateralForfeited(seller, sellerCollateral);
            } else {
                require(token.transfer(seller, amountAfterFee), "Token transfer to seller failed");
                require(token.transfer(seller, sellerCollateral), "Collateral refund to seller failed");
            }

            require(token.transfer(msg.sender, fee), "Fee transfer failed"); // Fee collected by the contract deployer

            state = EscrowState.COMPLETE;
            emit DisputeResolved(msg.sender, refundToBuyer);
            emit FeeCollected(msg.sender, fee);
        }
    }

    function forfeitCollateral() external inState(EscrowState.AWAITING_DELIVERY) {
        // Auto-resolve if delivery deadline passes without confirmation or dispute
        if (block.timestamp > deliveryDeadline && !isDisputeRaised) {
            state = EscrowState.COMPLETE;
            uint256 sellerCollateral = (escrowAmount * collateralPercentage) / 10000;
            require(token.transfer(seller, escrowAmount + sellerCollateral), "Token transfer failed");
        }
    }

    function getState() external view returns (string memory) {
        if (state == EscrowState.AWAITING_PAYMENT) return "AWAITING_PAYMENT";
        if (state == EscrowState.AWAITING_DELIVERY) return "AWAITING_DELIVERY";
        if (state == EscrowState.COMPLETE) return "COMPLETE";
        if (state == EscrowState.DISPUTE) return "DISPUTE";
        return "UNKNOWN";
    }

    function getApprovalStatus(address arbiter) external view returns (bool) {
        return hasApproved[arbiter];
    }

    function getArbiters() external view returns (address[] memory) {
        return arbiters;
    }
}
*/
