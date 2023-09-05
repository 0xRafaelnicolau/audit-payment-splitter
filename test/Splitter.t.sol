// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test, console2} from "../lib/forge-std/src/Test.sol";
import {Splitter} from "../src/Splitter.sol";

interface IUSDC {
    function balanceOf(address account) external view returns (uint256);
    function mint(address to, uint256 amount) external;
    function approve(address spender, uint256 amount) external;
    function configureMinter(address minter, uint256 minterAllowedAmount) external;
    function masterMinter() external view returns (address);
}

contract SplitterTest is Test {
    Splitter public splitter;
    IUSDC public usdc;

    address public provider;
    address public client;

    function setUp() public {
        provider = address(100);
        client = address(200);
        usdc = IUSDC(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

        vm.label(provider, "provider");
        vm.label(client, "client");
        vm.label(address(usdc), "USDC");

        vm.prank(provider);
        splitter = new Splitter(10);

        vm.prank(usdc.masterMinter());
        usdc.configureMinter(address(this), type(uint256).max);

        usdc.mint(client, 70000e6);
        assertEq(usdc.balanceOf(client), 70000e6);
    }

    function testProvideAudit() public {
        vm.prank(provider);
        uint256 auditId = splitter.provideAudit(client, address(usdc), 70000e6, 6);
        assertEq(auditId, 1);

        Splitter.Audit memory audit = splitter.getAudit(auditId);
        assertEq(audit.client, client);
        assertEq(audit.token, address(usdc));
        assertEq(audit.amount, 70000e6);
        assertEq(audit.amountPerPhase, 10000e6);
        assertEq(audit.totalPhases, 6);
        assertEq(audit.currentPhase, 0);
        assertEq(audit.confirmed, false);
        assertEq(audit.finished, false);
    }

    function testCancelAuditBeforeApproval() public {
        testProvideAudit();

        vm.startPrank(client);
        vm.expectRevert(Splitter.AuditNotYetConfirmed.selector);
        splitter.cancelAudit(1);
        vm.stopPrank();
    }

    function testApproveAudit() public {
        testProvideAudit();

        vm.startPrank(client);
        usdc.approve(address(splitter), 70000e6);
        splitter.approveAudit(1);
        vm.stopPrank();

        Splitter.Audit memory audit = splitter.getAudit(1);
        assertEq(audit.confirmed, true);
        assertEq(audit.amount, 60000e6);
        assertEq(audit.currentPhase, 0);
        assertEq(usdc.balanceOf(address(splitter)), 60000e6);
        assertEq(usdc.balanceOf(provider), 10000e6);
    }

    function testRejectAudit() public {
        testProvideAudit();

        vm.prank(client);
        splitter.rejectAudit(1);

        Splitter.Audit memory audit = splitter.getAudit(1);
        assertEq(audit.client, address(0));
    }

    function testRejectAlreadyApprovedAudit() public {
        testApproveAudit();

        vm.startPrank(client);
        vm.expectRevert(Splitter.AuditAlreadyConfirmed.selector);
        splitter.rejectAudit(1);
        vm.stopPrank();
    }

    function testRejectAuditTwice() public {
        testRejectAudit();

        vm.startPrank(client);
        vm.expectRevert(Splitter.AuditAlreadyRejected.selector);
        splitter.rejectAudit(1);
        vm.stopPrank();
    }

    function testCancelAuditAfterApproval() public {
        testApproveAudit();

        vm.prank(client);
        splitter.cancelAudit(1);

        Splitter.Audit memory audit = splitter.getAudit(1);
        assertEq(audit.finished, true);
        assertEq(audit.amount, 0);
        assertEq(usdc.balanceOf(client), 60000e6);
    }

    function testApproveAuditTwice() public {
        testApproveAudit();

        vm.startPrank(client);
        vm.expectRevert(Splitter.AuditAlreadyConfirmed.selector);
        splitter.approveAudit(1);
        vm.stopPrank();
    }

    function testSubmitPhase() public {
        testApproveAudit();

        vm.prank(provider);
        splitter.submitPhase(1);

        Splitter.Phase memory phase = splitter.getAuditPhase(1, 0);
        assertEq(phase.submitted, true);
        assertEq(phase.confirmed, false);
    }

    function testSubmitPhaseTwice() public {
        testSubmitPhase();

        vm.startPrank(provider);
        vm.expectRevert(Splitter.PhaseAlreadySubmitted.selector);
        splitter.submitPhase(1);
        vm.stopPrank();
    }

    function testApprovePhase() public {
        testSubmitPhase();

        vm.prank(client);
        splitter.approvePhase(1);

        Splitter.Phase memory phase = splitter.getAuditPhase(1, 0);
        assertEq(phase.submitted, true);
        assertEq(phase.confirmed, true);

        Splitter.Audit memory audit = splitter.getAudit(1);
        assertEq(audit.currentPhase, 1);
        assertEq(audit.amount, 50000e6);
        assertEq(usdc.balanceOf(provider), 20000e6);
    }

    function testApprovePhaseTwice() public {
        testApprovePhase();

        vm.startPrank(client);
        vm.expectRevert(Splitter.PhaseNotYetSubmitted.selector);
        splitter.approvePhase(1);
        vm.stopPrank();
    }

    function testApprovePhaseAuditFinished() public {
        testApproveAudit();

        _submitAndApprovePhase(1);
        _submitAndApprovePhase(2);
        _submitAndApprovePhase(3);
        _submitAndApprovePhase(4);
        _submitAndApprovePhase(5);
        _submitAndApprovePhase(6);

        assertEq(splitter.getAudit(1).finished, true);
        assertEq(usdc.balanceOf(address(splitter)), 0);
        assertEq(usdc.balanceOf(provider), 70000e6);
    }

    function testCancelAuditAfterAuditIsFinished() public {
        testApprovePhaseAuditFinished();

        vm.startPrank(client);
        vm.expectRevert(Splitter.AuditAlreadyFinished.selector);
        splitter.cancelAudit(1);
        vm.stopPrank();
    }

    function testSubmitPhaseAfterAuditIsFinished() public {
        testApprovePhaseAuditFinished();

        vm.startPrank(provider);
        vm.expectRevert(Splitter.AuditAlreadyFinished.selector);
        splitter.submitPhase(1);
        vm.stopPrank();
    }

    function _submitAndApprovePhase(uint256 phase) private {
        vm.prank(provider);
        splitter.submitPhase(1);
        vm.prank(client);
        splitter.approvePhase(1);
        assertEq(splitter.getAudit(1).currentPhase, phase);
    }
}
