// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Setup} from "../Setup.t.sol";
import {Splitter} from "../../src/Splitter.sol";

contract Unit is Setup {
    address public proposer = address(200);
    address public client = address(300);

    function setUp() public override {
        super.setUp();

        vm.label(proposer, "proposer");
        vm.label(client, "client");

        vm.startPrank(deployer);
        usdc.mint(client, 50000e6);
        splitter.addProposer(proposer);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    PROPOSE AUDIT
    //////////////////////////////////////////////////////////////////////////*/

    function testProposeAudit() public {
        uint256[] memory prices = new uint256[](5);
        prices[0] = 30000e6;
        prices[1] = 5000e6;
        prices[2] = 5000e6;
        prices[3] = 5000e6;
        prices[4] = 5000e6;

        vm.prank(proposer);
        uint256 id = splitter.proposeAudit(client, address(usdc), prices);

        Splitter.Audit memory audit = splitter.getAudit(id);
        assertEq(audit.client, client);
        assertEq(audit.proposer, proposer);
        assertEq(audit.token, address(usdc));
        assertEq(audit.price, 50000e6);
        assertEq(audit.totalPhases, prices.length);
        assertEq(audit.currentPhase, 0);
        assertEq(audit.accepted, false);
        assertEq(audit.finished, false);
    }

    function testProposeAuditWithZeroPricePhases() public {
        uint256[] memory prices = new uint256[](5);
        prices[0] = 30000e6;
        prices[1] = 0;
        prices[2] = 10000e6;
        prices[3] = 0;
        prices[4] = 10000e6;

        vm.prank(proposer);
        uint256 id = splitter.proposeAudit(client, address(usdc), prices);

        Splitter.Phase[] memory phases = splitter.getAllAuditPhases(id);
        for (uint256 i; i < phases.length; ++i) {
            assertEq(phases[i].price, prices[i]);
        }
    }

    function testProposeAuditEmptyPhasePricesArray() public {
        uint256[] memory prices = new uint256[](0);

        vm.startPrank(proposer);
        vm.expectRevert(Splitter.TotalPhasesIsZero.selector);
        splitter.proposeAudit(client, address(usdc), prices);
        vm.stopPrank();
    }

    function testProposeAuditExceededMaxPhases() public {
        uint256[] memory prices = new uint256[](11);

        vm.startPrank(proposer);
        vm.expectRevert(Splitter.ExceededMaxPhases.selector);
        splitter.proposeAudit(client, address(usdc), prices);
        vm.stopPrank();
    }

    function testProposeAuditTotalPriceCantBeZero() public {
        uint256[] memory prices = new uint256[](3);

        vm.startPrank(proposer);
        vm.expectRevert(Splitter.AuditTotalPriceCantBeZero.selector);
        splitter.proposeAudit(client, address(usdc), prices);
        vm.stopPrank();
    }

    function testProposeAuditInvalidProposer() public {
        address invalidProposer = address(400);
        uint256[] memory prices = new uint[](0);

        vm.startPrank(invalidProposer);
        vm.expectRevert(); // TODO: test for the specific error.
        vm.stopPrank();
        splitter.proposeAudit(client, address(usdc), prices);
    }

    function testProposeAuditInvalidToken() public {
        address invalidToken = address(500);
        uint256[] memory prices = new uint[](0);

        vm.startPrank(proposer);
        vm.expectRevert();
        splitter.proposeAudit(client, invalidToken, prices);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    ACCEPT AUDIT
    //////////////////////////////////////////////////////////////////////////*/

    function testAcceptAudit() public {
        testProposeAudit();

        vm.startPrank(client);
        usdc.approve(address(splitter), 50000e6);
        splitter.acceptAudit(1);
        vm.stopPrank();

        Splitter.Audit memory audit = splitter.getAudit(1);
        assertEq(audit.accepted, true);
        assertEq(usdc.balanceOf(client), 0);
        assertEq(usdc.balanceOf(address(splitter)), 50000e6);
    }

    function testAcceptAuditInvalidClient() public {
        testProposeAudit();

        address invalidClient = address(400);

        vm.startPrank(invalidClient);
        vm.expectRevert(Splitter.AuditInvalidClient.selector);
        splitter.acceptAudit(1);
        vm.stopPrank();
    }

    function testAcceptAuditTwice() public {
        testAcceptAudit();

        vm.startPrank(client);
        vm.expectRevert(Splitter.AuditAlreadyAccepted.selector);
        splitter.acceptAudit(1);
        vm.stopPrank();
    }

    function testAcceptRejectedAudit() public {
        testRejectAudit();

        vm.startPrank(client);
        vm.expectRevert(Splitter.AuditAlreadyFinished.selector);
        splitter.acceptAudit(1);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    REJECT AUDIT
    //////////////////////////////////////////////////////////////////////////*/

    function testRejectAudit() public {
        testProposeAudit();

        vm.prank(client);
        splitter.rejectAudit(1);

        Splitter.Audit memory audit = splitter.getAudit(1);
        assertEq(audit.finished, true);
    }

    function testRejectAuditInvalidClient() public {
        testProposeAudit();

        address invalidClient = address(400);

        vm.startPrank(invalidClient);
        vm.expectRevert(Splitter.AuditInvalidClient.selector);
        splitter.rejectAudit(1);
        vm.stopPrank();
    }

    function testRejectFinishedAudit() public {
        testRejectAudit();

        vm.startPrank(client);
        vm.expectRevert(Splitter.AuditAlreadyFinished.selector);
        splitter.rejectAudit(1);
        vm.stopPrank();
    }

    function testRejectAcceptedAudit() public {
        testAcceptAudit();

        vm.startPrank(client);
        vm.expectRevert(Splitter.AuditAlreadyAccepted.selector);
        splitter.rejectAudit(1);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    SUBMIT PHASE
    //////////////////////////////////////////////////////////////////////////*/

    function testSubmitPhase() public {
        testAcceptAudit();

        vm.prank(proposer);
        splitter.submitPhase(1);

        Splitter.Phase memory currentPhase = splitter.getAuditCurrentPhase(1);
        assertEq(currentPhase.submitted, true);
    }

    function testSubmitPhaseInvalidProposer() public {
        testAcceptAudit();

        address invalidProposer = address(400);

        vm.startPrank(invalidProposer);
        vm.expectRevert(); // TODO: test for the specific error.
        splitter.submitPhase(1);
        vm.stopPrank();
    }

    function testSubmitPhaseTwice() public {
        testSubmitPhase();

        vm.startPrank(proposer);
        vm.expectRevert(Splitter.PhaseAlreadySubmitted.selector);
        splitter.submitPhase(1);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    CANCEL AUDIT
    //////////////////////////////////////////////////////////////////////////*/

    function testCancelAudit() public {
        testAcceptAudit();

        vm.prank(client);
        splitter.cancelAudit(1);

        Splitter.Audit memory audit = splitter.getAudit(1);
        assertEq(audit.finished, true);
        assertEq(audit.price, 0);
        assertEq(usdc.balanceOf(client), 50000e6);
        assertEq(usdc.balanceOf(address(splitter)), 0);
    }

    function testCancelAuditTwice() public {
        testCancelAudit();

        vm.startPrank(client);
        vm.expectRevert(Splitter.AuditAlreadyFinished.selector);
        splitter.cancelAudit(1);
        vm.stopPrank();
    }

    function testCancelAuditInvalidClient() public {
        testAcceptAudit();

        address invalidClient = address(400);

        vm.startPrank(invalidClient);
        vm.expectRevert(Splitter.AuditInvalidClient.selector);
        splitter.cancelAudit(1);
        vm.stopPrank();
    }

    function testCancelAuditBeforeBeingAccepted() public {
        testProposeAudit();

        vm.startPrank(client);
        vm.expectRevert(Splitter.AuditNotYetAccepted.selector);
        splitter.cancelAudit(1);
        vm.stopPrank();
    }

    function testCancelAuditAfterSubmission() public {
        testSubmitPhase();

        vm.prank(client);
        splitter.cancelAudit(1);

        Splitter.Audit memory audit = splitter.getAudit(1);
        assertEq(audit.finished, true);
        assertEq(audit.price, 0);
        assertEq(usdc.balanceOf(client), 50000e6);
        assertEq(usdc.balanceOf(address(splitter)), 0);
    }

    function testCancelAuditAfterFirstPhaseAccepted() public {
        testApprovePhase();

        vm.prank(client);
        splitter.cancelAudit(1);

        uint256 phasePrice = splitter.getAuditPhase(1, 0).price;
        assertEq(usdc.balanceOf(address(splitter)), 0);
        assertEq(usdc.balanceOf(deployer), phasePrice);
        assertEq(usdc.balanceOf(client), 50000e6 - phasePrice);
    }

    function testCancelAuditRejectedAudit() public {
        testRejectAudit();

        vm.startPrank(client);
        vm.expectRevert(Splitter.AuditAlreadyFinished.selector);
        splitter.cancelAudit(1);
        vm.stopPrank();
    }

    function testCancelAuditAfterBeingFinished() public {
        testApprovePhaseAuditFinished();

        vm.startPrank(client);
        vm.expectRevert(Splitter.AuditAlreadyFinished.selector);
        splitter.cancelAudit(1);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    ACCEPT PHASE
    //////////////////////////////////////////////////////////////////////////*/

    function testApprovePhase() public {
        testSubmitPhase();

        uint256 priceBefore = splitter.getAudit(1).price;

        vm.prank(client);
        splitter.approvePhase(1);

        Splitter.Phase memory phase = splitter.getAuditPhase(1, 0);
        assertEq(phase.confirmed, true);

        Splitter.Audit memory audit = splitter.getAudit(1);
        assertEq(audit.price, priceBefore - phase.price);
        assertEq(usdc.balanceOf(deployer), phase.price);
        assertEq(usdc.balanceOf(address(splitter)), priceBefore - phase.price);
    }

    function testApprovePhaseTwice() public {
        testApprovePhase();

        vm.startPrank(client);
        vm.expectRevert(Splitter.PhaseNotYetSubmitted.selector);
        splitter.approvePhase(1);
        vm.stopPrank();
    }

    function testApprovePhaseCanceledAudit() public {
        testCancelAudit();

        vm.startPrank(client);
        vm.expectRevert(Splitter.AuditAlreadyFinished.selector);
        splitter.approvePhase(1);
        vm.stopPrank();
    }

    function testApprovePhaseRejectedAudit() public {
        testRejectAudit();

        vm.startPrank(client);
        vm.expectRevert(Splitter.AuditAlreadyFinished.selector);
        splitter.approvePhase(1);
        vm.stopPrank();
    }

    function testApprovePhaseInvalidClient() public {
        testSubmitPhase();

        address invalidClient = address(400);

        vm.startPrank(invalidClient);
        vm.expectRevert(Splitter.AuditInvalidClient.selector);
        splitter.approvePhase(1);
        vm.stopPrank();
    }

    function testApprovePhaseAuditFinished() public {
        testAcceptAudit();

        vm.prank(proposer);
        splitter.submitPhase(1);
        vm.prank(client);
        splitter.approvePhase(1); // 0 to 1

        vm.prank(proposer);
        splitter.submitPhase(1);
        vm.prank(client);
        splitter.approvePhase(1); // 1 to 2

        vm.prank(proposer);
        splitter.submitPhase(1);
        vm.prank(client);
        splitter.approvePhase(1); // 2 to 3

        vm.prank(proposer);
        splitter.submitPhase(1);
        vm.prank(client);
        splitter.approvePhase(1); // 3 to 4

        vm.prank(proposer);
        splitter.submitPhase(1);
        vm.prank(client);
        splitter.approvePhase(1); // 4 to 5

        Splitter.Audit memory audit = splitter.getAudit(1);
        assertEq(audit.currentPhase, 5);
        assertEq(audit.price, 0);
        assertEq(audit.finished, true);
    }
}
