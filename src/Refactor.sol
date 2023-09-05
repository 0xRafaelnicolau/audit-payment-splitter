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
        address token;
        uint256 price;
        uint256 totalPhases;
        uint256 currentPhase;
        bool confirmed;
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

    /*//////////////////////////////////////////////////////////////////////////
                                    EVENTS
    //////////////////////////////////////////////////////////////////////////*/

    event AuditProposed(uint256 auditId, address client);

    /*//////////////////////////////////////////////////////////////////////////
                                    STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    bytes32 public constant COVERAGE_ROLE = keccak256("COVERAGE_ROLE");
    mapping(uint256 => Audit) public audits;
    mapping(uint256 => mapping(uint256 => Phase)) public phases;

    uint256 private _auditId;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/
    constructor(address coverage) {
        _grantRole(COVERAGE_ROLE, coverage);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    PUBLIC/EXTERNAL
    //////////////////////////////////////////////////////////////////////////*/

    function proposeAudit(address client, address token, uint256[] calldata pricePerPhase, uint256 totalPhases)
        external
        onlyRole(COVERAGE_ROLE)
        returns (uint256)
    {
        if (pricePerPhase.length != totalPhases) revert LengthDoesNotMatchPhases();
        if (totalPhases == 0) revert TotalPhasesIsZero();
        if (client == address(0)) revert AddressZero();
        if (token == address(0)) revert AddressZero();

        _auditId += 1;

        uint256 totalPrice;
        for (uint256 i; i < totalPhases; ++i) {
            uint256 phasePrice = pricePerPhase[i];
            if (phasePrice == 0) revert PhaseWithZeroPrice();

            totalPrice += phasePrice;
            phases[_auditId][i].price = phasePrice;
        }

        Audit memory audit = Audit(client, token, totalPrice, totalPhases, 0, false, false);
        audits[_auditId] = audit;

        emit AuditProposed(_auditId, client);

        return _auditId;
    }

    function acceptAudit(uint256 auditId) external {}

    function rejectAudit(uint256 auditId) external {}

    function submitPhase(uint256 auditId) external onlyRole(COVERAGE_ROLE) {}

    function approvePhase(uint256 auditId) external {}
}
