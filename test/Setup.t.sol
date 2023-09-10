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

contract Setup is Test {
    Splitter public splitter;

    IUSDC public usdc = IUSDC(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    address public deployer = address(100);

    function setUp() public virtual {
        vm.label(deployer, "coverage");
        vm.label(address(usdc), "USDC");

        vm.prank(usdc.masterMinter());
        usdc.configureMinter(deployer, type(uint256).max);

        vm.prank(deployer);
        splitter = new Splitter(10);
    }
}
