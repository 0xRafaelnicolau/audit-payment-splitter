// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract Splitter is Ownable {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////////////////
                                        STRUCTS
    //////////////////////////////////////////////////////////////////////////*/

    struct Audit {
        address client;
        address token;
        uint256 amount;
        uint256 amountPerPhase;
        uint256 totalPhases;
        uint256 currentPhase;
        bool confirmed;
        bool finished;
    }

    struct Phase {
        bool submitted;
        bool confirmed;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                        ERRORS
    //////////////////////////////////////////////////////////////////////////*/

    error AddressZero();
    error ZeroAmount();
    error ExceededMaxPhases();
    error AuditInvalidClient();
    error AuditAlreadyConfirmed();
    error AuditAlreadyRejected();
    error AuditNotYetConfirmed();
    error AuditAlreadyFinished();
    error PhaseAlreadyConfirmed();
    error PhaseAlreadySubmitted();
    error PhaseNotYetSubmitted();

    /*//////////////////////////////////////////////////////////////////////////
                                        EVENTS
    //////////////////////////////////////////////////////////////////////////*/

    event AuditProvided(uint256 auditId);
    event AuditApproved(uint256 auditId);
    event AuditRejected(uint256 auditId);
    event AuditCanceled(uint256 auditId);
    event AuditFinished(uint256 auditId);
    event PhaseSubmitted(uint256 auditId, uint256 phase);
    event PhaseApproved(uint256 auditId, uint256 phase);

    /*//////////////////////////////////////////////////////////////////////////
                                        STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    // @notice audit id => Audit.
    mapping(uint256 => Audit) public audits;
    // @notice audit id => phase id => Phase
    mapping(uint256 => mapping(uint256 => Phase)) public phases;
    // @notice current audit id.
    uint256 private _currentAuditId;
    // @notice max phases allowed per audit.
    uint256 private _maxPhases;

    constructor(uint256 maxPhases) {
        _maxPhases = maxPhases;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                PUBLIC/EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    function provideAudit(address client, address token, uint256 amount, uint256 totalPhases)
        external
        onlyOwner
        returns (uint256)
    {
        if (client == address(0)) revert AddressZero();
        if (token == address(0)) revert AddressZero();
        if (amount == 0) revert ZeroAmount();
        if (totalPhases > _maxPhases) revert ExceededMaxPhases();

        uint256 amountPerPhase = amount / (totalPhases + 1);
        Audit memory audit = Audit(client, token, amount, amountPerPhase, totalPhases, 0, false, false);

        _currentAuditId++;
        audits[_currentAuditId] = audit;

        emit AuditProvided(_currentAuditId);

        return _currentAuditId;
    }

    function approveAudit(uint256 auditId) external {
        Audit storage audit = audits[auditId];

        if (audit.client != msg.sender) revert AuditInvalidClient();
        if (audit.confirmed == true) revert AuditAlreadyConfirmed();

        audit.confirmed = true;
        audit.amount -= audit.amountPerPhase;

        IERC20(audit.token).safeTransferFrom(audit.client, address(this), audit.amount);
        IERC20(audit.token).safeTransferFrom(audit.client, owner(), audit.amountPerPhase);

        emit AuditApproved(auditId);
    }

    function rejectAudit(uint256 auditId) external {
        Audit memory audit = audits[auditId];

        if (audit.client == address(0)) revert AuditAlreadyRejected();
        if (audit.client != msg.sender) revert AuditInvalidClient();
        if (audit.confirmed == true) revert AuditAlreadyConfirmed();

        delete audits[auditId];

        emit AuditRejected(auditId);
    }

    function cancelAudit(uint256 auditId) external {
        Audit storage audit = audits[auditId];

        if (msg.sender != audit.client) revert AuditInvalidClient();
        if (audit.confirmed == false) revert AuditNotYetConfirmed();
        if (audit.finished == true) revert AuditAlreadyFinished();

        uint256 amount = audit.amount;

        audit.finished = true;
        audit.amount = 0;

        IERC20(audit.token).safeTransfer(audit.client, amount);

        emit AuditCanceled(auditId);
    }

    function submitPhase(uint256 auditId) external onlyOwner {
        Audit memory audit = audits[auditId];
        Phase storage phase = phases[auditId][audit.currentPhase];

        if (audit.finished == true) revert AuditAlreadyFinished();
        if (phase.confirmed == true) revert PhaseAlreadyConfirmed();
        if (phase.submitted == true) revert PhaseAlreadySubmitted();

        phase.submitted = true;

        emit PhaseSubmitted(auditId, audit.currentPhase);
    }

    function approvePhase(uint256 auditId) external {
        Audit storage audit = audits[auditId];
        Phase storage phase = phases[auditId][audit.currentPhase];

        if (msg.sender != audit.client) revert AuditInvalidClient();
        if (audit.finished == true) revert AuditAlreadyFinished();
        if (phase.submitted == false) revert PhaseNotYetSubmitted();
        if (phase.confirmed == true) revert PhaseAlreadyConfirmed();

        uint256 phaseBefore = audit.currentPhase;

        phase.confirmed = true;
        audit.currentPhase += 1;
        audit.amount -= audit.amountPerPhase;

        if (audit.currentPhase == audit.totalPhases) {
            audit.finished = true;
            emit AuditFinished(auditId);
        }

        IERC20(audit.token).safeTransfer(owner(), audit.amountPerPhase);

        emit PhaseApproved(auditId, phaseBefore);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                GETTERS / SETTERS
    //////////////////////////////////////////////////////////////////////////*/

    function setMaxPhases(uint256 maxPhases) external onlyOwner {
        _maxPhases = maxPhases;
    }

    function getAudit(uint256 auditId) external view returns (Audit memory) {
        return audits[auditId];
    }

    function getAuditPhase(uint256 auditId, uint256 phase) external view returns (Phase memory) {
        if (phase >= audits[auditId].totalPhases) revert ExceededMaxPhases();
        return phases[auditId][phase];
    }
}
