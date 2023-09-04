// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test, console2} from "../lib/forge-std/src/Test.sol";
import {Audits} from "../src/Audits.sol";

interface IUSDC {
    function balanceOf(address account) external view returns (uint256);
    function mint(address to, uint256 amount) external;
    function approve(address spender, uint256 amount) external;
    function configureMinter(address minter, uint256 minterAllowedAmount) external;
    function masterMinter() external view returns (address);
}

contract AuditsTest is Test {
    Audits public audits;
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
        audits = new Audits(10);

        vm.prank(usdc.masterMinter());
        usdc.configureMinter(address(this), type(uint256).max);

        usdc.mint(client, 60000e6);
        assertEq(usdc.balanceOf(client), 60000e6);
    }

    function testProvideAudit() public {
        vm.prank(provider);
        uint256 auditId = audits.provideAudit(client, address(usdc), 60000e6, 6);
        assertEq(auditId, 1);

        Audits.Audit memory audit = audits.getAudit(auditId);
        assertEq(audit.client, client);
        assertEq(audit.token, address(usdc));
        assertEq(audit.amount, 60000e6);
        assertEq(audit.amountPerPhase, 10000e6);
        assertEq(audit.totalPhases, 6);
        assertEq(audit.currentPhase, 0);
        assertEq(audit.confirmed, false);
        assertEq(audit.finished, false);
    }

    function testApproveAudit() public {
        testProvideAudit();

        vm.startPrank(client);
        usdc.approve(address(audits), 60000e6);
        audits.approveAudit(1);
        vm.stopPrank();

        Audits.Audit memory audit = audits.getAudit(1);
        assertEq(audit.confirmed, true);
        assertEq(usdc.balanceOf(address(audits)), 60000e6);
    }

    function testApproveAuditTwice() public {
        testApproveAudit();

        vm.startPrank(client);
        vm.expectRevert(Audits.AuditAlreadyConfirmed.selector);
        audits.approveAudit(1);
        vm.stopPrank();
    }

    function testSubmitPhase() public {
        testApproveAudit();

        vm.prank(provider);
        audits.submitPhase(1);

        Audits.Phase memory phase = audits.getAuditPhase(1);
        assertEq(phase.submitted, true);
        assertEq(phase.confirmed, false);
    }

    function testSubmitPhaseTwice() public {
        testSubmitPhase();

        vm.startPrank(provider);
        vm.expectRevert(Audits.PhaseAlreadySubmitted.selector);
        audits.submitPhase(1);
        vm.stopPrank();
    }
}
