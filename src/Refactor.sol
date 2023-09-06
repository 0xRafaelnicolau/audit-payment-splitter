// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {AccessControl} from "../lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract Refactor is AccessControl {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////////////////
                                        STRUCTS
    //////////////////////////////////////////////////////////////////////////*/

    struct Audit {
        address client;
        address proposer;
        address token;
        uint256 price;
        uint256 totalPhases;
        uint256 currentPhase;
        bool accepted;
        bool finished;
    }

    struct Phase {
        uint256 price;
        bool submitted;
        bool confirmed;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    ERRORS
    //////////////////////////////////////////////////////////////////////////*/

    error LengthDoesNotMatchPhases();
    error TotalPhasesIsZero();
    error AddressZero();
    error PhaseWithZeroPrice();
    error AuditInvalidClient();
    error AuditAlreadyAccepted();
    error AuditAlreadyFinished();
    error AuditNotYetAccepted();
    error AuditInvalidProposer();
    error PhaseAlreadySubmitted();
    error PhaseAlreadyConfirmed();

    /*//////////////////////////////////////////////////////////////////////////
                                    EVENTS
    //////////////////////////////////////////////////////////////////////////*/

    event AuditProposed(uint256 auditId, address client, address proposer);
    event AuditAccepted(uint256 auditId, address client, address proposer);
    event AuditRejected(uint256 auditId, address client, address proposer);
    event AuditCanceled(uint256 auditId, address client, address proposer);
    event PhaseApproved(uint256 auditId, uint256 phase, address client, address proposer);
    event PhaseSubmitted(uint256 auditId, uint256 phase, address client, address proposer);

    /*//////////////////////////////////////////////////////////////////////////
                                    STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    bytes32 public constant COVERAGE_ROLE = keccak256("COVERAGE_ROLE");
    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    mapping(uint256 => Audit) public audits;
    mapping(uint256 => mapping(uint256 => Phase)) public phases;

    address private _coverage;
    uint256 private _auditId;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/
    constructor() {
        _grantRole(COVERAGE_ROLE, msg.sender);
        _coverage = msg.sender;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    COVERAGE FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    function addProposer(address proposer) external onlyRole(COVERAGE_ROLE) {
        if (proposer == address(0)) revert AddressZero();
        _grantRole(PROPOSER_ROLE, proposer);
    }

    function removeProposer(address proposer) external onlyRole(COVERAGE_ROLE) {
        if (proposer == address(0)) revert AddressZero();
        _revokeRole(PROPOSER_ROLE, proposer);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    PUBLIC / EXTERNAL
    //////////////////////////////////////////////////////////////////////////*/

    function proposeAudit(address client, address token, uint256[] calldata phasePrices, uint256 totalPhases)
        external
        onlyRole(PROPOSER_ROLE)
        returns (uint256)
    {
        if (phasePrices.length != totalPhases) revert LengthDoesNotMatchPhases();
        if (totalPhases == 0) revert TotalPhasesIsZero();
        if (client == address(0)) revert AddressZero();
        if (token == address(0)) revert AddressZero();

        _auditId += 1;
        uint256 totalPrice = _updatePhasePrices(_auditId, phasePrices, totalPhases);
        audits[_auditId] = Audit(client, msg.sender, token, totalPrice, totalPhases, 0, false, false);

        emit AuditProposed(_auditId, client, msg.sender);

        return _auditId;
    }

    function acceptAudit(uint256 auditId) external {
        Audit memory audit = audits[auditId];
        if (audit.client != msg.sender) revert AuditInvalidClient();
        if (audit.accepted == true) revert AuditAlreadyAccepted();

        audits[auditId].accepted = true;

        IERC20(audits[auditId].token).safeTransferFrom(audit.client, address(this), audit.price);

        emit AuditAccepted(auditId, audit.client, audit.proposer);
    }

    function rejectAudit(uint256 auditId) external {
        Audit memory audit = audits[auditId];
        if (audit.client != msg.sender) revert AuditInvalidClient();
        if (audit.finished == true) revert AuditAlreadyFinished();
        if (audit.accepted == true) revert AuditAlreadyAccepted();

        audits[auditId].finished = true;

        emit AuditRejected(auditId, audit.client, audit.proposer);
    }

    function cancelAudit(uint256 auditId) external {
        Audit memory audit = audits[auditId];
        if (audit.client != msg.sender) revert AuditInvalidClient();
        if (audit.accepted == false) revert AuditNotYetAccepted();
        if (audit.finished == true) revert AuditAlreadyFinished();

        uint256 amountToWithdraw = audit.price;

        audits[auditId].finished = true;
        audits[auditId].price = 0;

        IERC20(audit.token).safeTransfer(audit.client, amountToWithdraw);

        emit AuditCanceled(auditId, audit.client, audit.proposer);
    }

    function submitPhase(uint256 auditId) external onlyRole(PROPOSER_ROLE) {
        Audit memory audit = audits[auditId];
        Phase memory currPhase = phases[auditId][audit.currentPhase];
        if (audit.proposer != msg.sender) revert AuditInvalidProposer();
        if (audit.finished == true) revert AuditAlreadyFinished();
        if (currPhase.submitted == true) revert PhaseAlreadySubmitted();
        if (currPhase.confirmed == true) revert PhaseAlreadyConfirmed();

        currPhase.submitted = true;

        emit PhaseSubmitted(auditId, audit.currentPhase, audit.client, audit.proposer);
    }

    function approvePhase(uint256 auditId) external {}

    /*//////////////////////////////////////////////////////////////////////////
                                    PRIVATE / INTERNAL
    //////////////////////////////////////////////////////////////////////////*/

    function _updatePhasePrices(uint256 auditId, uint256[] memory phasePrices, uint256 totalPhases)
        private
        returns (uint256)
    {
        uint256 totalPrice;
        for (uint256 i; i < totalPhases; ++i) {
            if (phasePrices[i] == 0) revert PhaseWithZeroPrice();
            totalPrice += phasePrices[i];
            phases[auditId][i].price = phasePrices[i];
        }
        return totalPrice;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    GETTERS / SETTERS
    //////////////////////////////////////////////////////////////////////////*/

    function getAudit(uint256 auditId) external view returns (Audit memory) {
        return audits[auditId];
    }

    function getAuditPhase(uint256 auditId, uint256 phase) external view returns (Phase memory) {
        return phases[auditId][phase];
    }

    function getAllAuditPhases(uint256 auditId) external view returns (Phase[] memory) {
        Phase[] memory auditPhases = new Phase[](audits[auditId].totalPhases);
        for (uint256 i; i < audits[auditId].totalPhases; ++i) {
            auditPhases[i] = phases[auditId][i];
        }
        return auditPhases;
    }
}
