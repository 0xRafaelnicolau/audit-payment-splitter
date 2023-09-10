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

    function testProposeAudit() public {
        uint256[] memory prices = new uint256[](5);
        prices[0] = 30000e6;
        prices[1] = 5000e6;
        prices[2] = 5000e6;
        prices[3] = 5000e6;
        prices[4] = 5000e6;

        vm.startPrank(proposer);
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

        vm.startPrank(proposer);
        uint256 id = splitter.proposeAudit(client, address(usdc), prices);

        Splitter.Phase[] memory phases = splitter.getAllAuditPhases(id);
        for(uint i; i < phases.length; ++i) {
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
}
