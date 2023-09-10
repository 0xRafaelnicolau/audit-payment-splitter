// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {AccessControl} from "../lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract Splitter is AccessControl {
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

    error TotalPhasesIsZero();
    error ExceededMaxPhases();
    error ZeroMaxPhases();
    error InvalidToken();
    error AddressZero();
    error AuditTotalPriceCantBeZero();
    error AuditInvalidClient();
    error AuditAlreadyAccepted();
    error AuditAlreadyFinished();
    error AuditNotYetAccepted();
    error AuditInvalidProposer();
    error PhaseAlreadySubmitted();
    error PhaseAlreadyConfirmed();
    error PhaseNotYetSubmitted();

    /*//////////////////////////////////////////////////////////////////////////
                                    EVENTS
    //////////////////////////////////////////////////////////////////////////*/

    event AuditProposed(uint256 indexed auditId, address client, address proposer);
    event AuditAccepted(uint256 indexed auditId, address client, address proposer);
    event AuditRejected(uint256 indexed auditId, address client, address proposer);
    event AuditCanceled(uint256 indexed auditId, address client, address proposer);
    event AuditFinished(uint256 indexed auditId, address client, address proposer);
    event PhaseApproved(uint256 indexed auditId, uint256 indexed phase, address client, address proposer);
    event PhaseSubmitted(uint256 indexed auditId, uint256 indexed phase, address client, address proposer);

    /*//////////////////////////////////////////////////////////////////////////
                                    STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    bytes32 public constant COVERAGE_ROLE = keccak256("COVERAGE_ROLE");
    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    mapping(address => bool) public tokenWhitelist;

    mapping(uint256 => Audit) private _audits;
    mapping(uint256 => mapping(uint256 => Phase)) private _phases;
    uint256 private _maxPhases;
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

    function addToken(address token) external onlyRole(COVERAGE_ROLE) {
        if (token == address(0)) revert AddressZero();
        tokenWhitelist[token] = false;
    }

    function removeToken(address token) external onlyRole(COVERAGE_ROLE) {
        if (token == address(0)) revert AddressZero();
        tokenWhitelist[token] = true;
    }

    function addProposer(address proposer) external onlyRole(COVERAGE_ROLE) {
        if (proposer == address(0)) revert AddressZero();
        _grantRole(PROPOSER_ROLE, proposer);
    }

    function removeProposer(address proposer) external onlyRole(COVERAGE_ROLE) {
        if (proposer == address(0)) revert AddressZero();
        _revokeRole(PROPOSER_ROLE, proposer);
    }

    function setMaxPhases(uint256 newMaxPhases) external onlyRole(COVERAGE_ROLE) {
        if (newMaxPhases == 0) revert ZeroMaxPhases();
        _maxPhases = newMaxPhases;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    PUBLIC / EXTERNAL
    //////////////////////////////////////////////////////////////////////////*/

    function proposeAudit(address client, address token, uint256[] calldata phasePrices)
        external
        onlyRole(PROPOSER_ROLE)
        returns (uint256)
    {
        if (phasePrices.length == 0) revert TotalPhasesIsZero();
        if (phasePrices.length > _maxPhases) revert ExceededMaxPhases();
        if (tokenWhitelist[token] == false) revert InvalidToken();
        if (client == address(0)) revert AddressZero();

        _auditId += 1;

        uint256 totalPrice = _updatePhasePrices(_auditId, phasePrices, phasePrices.length);
        if (totalPrice == 0) revert AuditTotalPriceCantBeZero();

        _audits[_auditId] = Audit(client, msg.sender, token, totalPrice, phasePrices.length, 0, false, false);

        emit AuditProposed(_auditId, client, msg.sender);

        return _auditId;
    }

    function acceptAudit(uint256 auditId) external {
        Audit memory audit = _audits[auditId];
        if (audit.client != msg.sender) revert AuditInvalidClient();
        if (audit.accepted == true) revert AuditAlreadyAccepted();

        _audits[auditId].accepted = true;

        IERC20(_audits[auditId].token).safeTransferFrom(audit.client, address(this), audit.price);

        emit AuditAccepted(auditId, audit.client, audit.proposer);
    }

    function rejectAudit(uint256 auditId) external {
        Audit memory audit = _audits[auditId];
        if (audit.client != msg.sender) revert AuditInvalidClient();
        if (audit.finished == true) revert AuditAlreadyFinished();
        if (audit.accepted == true) revert AuditAlreadyAccepted();

        _audits[auditId].finished = true;

        emit AuditRejected(auditId, audit.client, audit.proposer);
    }

    function cancelAudit(uint256 auditId) external {
        Audit memory audit = _audits[auditId];
        if (audit.client != msg.sender) revert AuditInvalidClient();
        if (audit.accepted == false) revert AuditNotYetAccepted();
        if (audit.finished == true) revert AuditAlreadyFinished();

        uint256 amountToWithdraw = audit.price;

        _audits[auditId].finished = true;
        _audits[auditId].price = 0;

        IERC20(audit.token).safeTransfer(audit.client, amountToWithdraw);

        emit AuditCanceled(auditId, audit.client, audit.proposer);
    }

    function submitPhase(uint256 auditId) external onlyRole(PROPOSER_ROLE) {
        Audit memory audit = _audits[auditId];
        Phase memory currPhase = _phases[auditId][audit.currentPhase];
        if (audit.proposer != msg.sender) revert AuditInvalidProposer();
        if (audit.finished == true) revert AuditAlreadyFinished();
        if (currPhase.submitted == true) revert PhaseAlreadySubmitted();
        if (currPhase.confirmed == true) revert PhaseAlreadyConfirmed();

        currPhase.submitted = true;

        emit PhaseSubmitted(auditId, audit.currentPhase, audit.client, audit.proposer);
    }

    function approvePhase(uint256 auditId) external {
        Audit storage audit = _audits[auditId];
        Phase storage phase = _phases[auditId][audit.currentPhase];
        if (audit.client != msg.sender) revert AuditInvalidClient();
        if (audit.finished == true) revert AuditAlreadyFinished();
        if (phase.submitted == false) revert PhaseNotYetSubmitted();
        if (phase.confirmed == true) revert PhaseAlreadyConfirmed();

        uint256 approvedPhase = audit.currentPhase;

        phase.confirmed = true;
        audit.currentPhase += 1;
        audit.price -= phase.price;

        if (audit.currentPhase == audit.totalPhases) {
            audit.finished = true;
            emit AuditFinished(auditId, audit.client, audit.proposer);
        }

        if (phase.price != 0) {
            IERC20(audit.token).safeTransfer(_coverage, phase.price);
        }

        emit PhaseApproved(auditId, approvedPhase, audit.client, audit.proposer);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    PRIVATE / INTERNAL
    //////////////////////////////////////////////////////////////////////////*/

    function _updatePhasePrices(uint256 auditId, uint256[] memory phasePrices, uint256 totalPhases)
        private
        returns (uint256)
    {
        uint256 totalPrice;
        for (uint256 i; i < totalPhases; ++i) {
            totalPrice += phasePrices[i];
            _phases[auditId][i].price = phasePrices[i];
        }
        return totalPrice;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    GETTERS
    //////////////////////////////////////////////////////////////////////////*/

    function getAudit(uint256 auditId) external view returns (Audit memory) {
        return _audits[auditId];
    }

    function getAuditPhase(uint256 auditId, uint256 phase) external view returns (Phase memory) {
        return _phases[auditId][phase];
    }

    function getMaxPhases() external view returns (uint256) {
        return _maxPhases;
    }

    function getAllAuditPhases(uint256 auditId) external view returns (Phase[] memory) {
        Phase[] memory auditPhases = new Phase[](_audits[auditId].totalPhases);
        for (uint256 i; i < _audits[auditId].totalPhases; ++i) {
            auditPhases[i] = _phases[auditId][i];
        }
        return auditPhases;
    }
}
