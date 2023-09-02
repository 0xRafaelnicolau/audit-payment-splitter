// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract Payments is Ownable {
    enum Phase {
        CONTEXT_FASE,
        TEST_FASE,
        INVARIANT_TEST_FASE,
        MANUAL_REVIEW_FASE,
        MITIGATION_REVIEW_FASE,
        FINAL_REPORT_FASE
    }

    struct Audit {
        address client;
        uint256 price;
        uint256 pricePerPhase;
        Phase phase;
        bool deposited;
    }

    struct Handshake {
        uint256 auditId;
        Phase phase;
        bool confirmed;
    }

    // @notice audit id => Audit
    mapping(uint256 => Audit) public audits;
    // @notice audit id => Phase => Handshake
    mapping(uint256 => mapping(Phase => Handshake)) public handshakes;

    uint256 public auditId;
    IERC20 public paymentToken;

    constructor(address _paymentToken) {
        paymentToken = IERC20(_paymentToken);
    }

    modifier validateClient(uint256 _auditId) {
        require(msg.sender == audits[_auditId].client);
        _;
    }

    function createAudit(address _client, uint256 _price) external onlyOwner {
        require(_client != address(0), "Can't be address zero");
        require(_price != 0, "The price of the audit can't be zero");

        auditId += 1;

        Audit memory audit = Audit(_client, _price, _price / 6, Phase.CONTEXT_FASE, false);
        audits[auditId] = audit;
    }

    function deposit(uint256 _auditId, uint256 _amount) external validateClient(_auditId) {
        Audit storage audit = audits[auditId];
        require(audit.deposited == false, "Audit price has already been paid");
        require(_amount == audit.price, "Invalid price for the audit");

        audit.deposited = true;

        require(paymentToken.transferFrom(audit.client, address(this), audit.price) == true, "Transfer failed");
    }

    function withdraw(uint256 _auditId) external validateClient(_auditId) {
        Audit storage audit = audits[auditId];
        require(audit.deposited == true, "Client has not deposited yet");

        uint256 priceBefore = audit.price;
        audit.price = 0;

        require(paymentToken.transfer(audit.client, priceBefore) == true, "Transfer failed");
    }

    function submitHandshake(Handshake calldata _handshake) external onlyOwner {
        require(_handshake.confirmed == false);
        require(_handshake.phase <= type(Phase).max);
        require(_handshake.phase == audits[_handshake.auditId].phase, "Incorrect phase");
        require(handshakes[_handshake.auditId][_handshake.phase].confirmed == false, "Handshake already made");

        handshakes[auditId][_handshake.phase] = _handshake;
    }

    function confirmHandshake(uint256 _auditId) external validateClient(_auditId) {
        Phase currentPhase = audits[_auditId].phase;
        require(handshakes[_auditId][currentPhase].confirmed == false, "Phase already confirmed");

        Audit storage audit = audits[_auditId];
        handshakes[_auditId][currentPhase].confirmed = true;
        audit.phase = Phase(uint256(audit.phase) + 1);
        audit.price -= audit.pricePerPhase;

        require(paymentToken.transferFrom(audit.client, owner(), audit.pricePerPhase) == true, "Transfer failed");
    }
}