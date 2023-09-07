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

    address public deployer = address(100);
    address public provider = address(200);
    address public client = address(300);

    function setUp() public {
        vm.label(deployer, "coverage");
        vm.label(provider, "provider");
        vm.label(client, "client");
        vm.label(address(usdc), "USDC");

        // set USDC contract address from mainnet.
        usdc = IUSDC(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

        // deploy the splitter contract.
        vm.prank(provider);
        splitter = new Splitter();

        // set this contract as minter of USDC.
        vm.prank(usdc.masterMinter());
        usdc.configureMinter(address(this), type(uint256).max);

        // mint USDC to the client.
        usdc.mint(client, 40000e6);
        assertEq(usdc.balanceOf(client), 40000e6);
    }
}
