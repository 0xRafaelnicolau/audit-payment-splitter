// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Setup} from "../Setup.t.sol";
import {Splitter} from "../../src/Splitter.sol";

contract Fuzz is Setup {
    function testFuzzAddProposer(address proposer) public {
        vm.assume(proposer != address(0));

        vm.prank(deployer);
        splitter.addProposer(proposer);

        assertEq(splitter.hasRole(splitter.PROPOSER_ROLE(), proposer), true);
    }

    function testFuzzRemoveProposer(address proposer) public {
        testFuzzAddProposer(proposer);

        vm.assume(proposer != address(0));

        vm.prank(deployer);
        splitter.removeProposer(proposer);

        assertEq(splitter.hasRole(splitter.PROPOSER_ROLE(), proposer), false);
    }

    function testFuzzMaxPhases(uint256 newMaxPhases) public {
        vm.assume(newMaxPhases != 0);

        vm.prank(deployer);
        splitter.setMaxPhases(newMaxPhases);

        assertEq(splitter.getMaxPhases(), newMaxPhases);
    }
}
