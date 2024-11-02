// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/GameFiVault.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    constructor() ERC20("MockToken", "MTK") {
        _mint(msg.sender, 1000000 * 10 ** 18); // Mint 1,000,000 tokens to the deployer
    }
}

contract GameFiVaultTest is Test {
    GameFiVault vault;
    MockToken token;
    address user1 = address(0x123);
    address user2 = address(0x456);

    function setUp() public {
        token = new MockToken();
        vault = new GameFiVault(IERC20(address(token)));

        // Allocate initial tokens to users
        token.transfer(user1, 1000 * 10 ** 18);
        token.transfer(user2, 1000 * 10 ** 18);

        // Fund the contract with enough tokens to cover withdrawals
        token.transfer(address(vault), 500 * 10 ** 18);
    }

    function testDeposit() public {
        // User1 approves and deposits 100 tokens
        vm.startPrank(user1);
        token.approve(address(vault), 100 * 10 ** 18);
        vault.deposit(100 * 10 ** 18);

        // Check vault's total shares and user's shares
        (uint256 userShares,,) = vault.stakers(user1);
        assertEq(userShares, 100 * 10 ** 18, "User shares should match deposited amount");

        uint256 totalShares = vault.totalShares();
        assertEq(totalShares, 100 * 10 ** 18, "Total shares should match the deposited amount");

        uint256 vaultBal = vault.vaultBalance();
        assertEq(vaultBal, 100 * 10 ** 18, "Vault balance should reflect the deposit");
        vm.stopPrank();
    }

    function testYieldCalculation() public {
        vm.startPrank(user1);
        token.approve(address(vault), 100 * 10 ** 18);
        vault.deposit(100 * 10 ** 18);

        // Increase the time by 365 days to simulate one year passing
        skip(365 days);

        uint256 yield = vault.calculateYieldForUser(user1);
        uint256 expectedYield = (100 * 10 ** 18 * 10) / 100; // 10% of 100 tokens
        assertEq(yield, expectedYield, "Yield should match expected 10% annual return");

        vm.stopPrank();
    }

    function testWithdraw() public {
        vm.startPrank(user1);
        token.approve(address(vault), 100 * 10 ** 18);
        vault.deposit(100 * 10 ** 18);

        // Simulate 365 days to generate yield
        skip(365 days);

        // Log expected and calculated values
        uint256 yield = vault.calculateYieldForUser(user1);
        emit log_named_uint("Calculated Yield", yield);

        // User withdraws all shares
        vault.withdraw(100 * 10 ** 18);

        // Expected balance calculation
        uint256 expectedYield = (100 * 10 ** 18 * 10) / 100; // 10% yield of the deposited amount
        uint256 expectedTotal = 100 * 10 ** 18 + expectedYield; // Principal + yield

        vm.stopPrank();
    }

    function testFailWithdrawWithoutSufficientShares() public {
        vm.startPrank(user1);
        token.approve(address(vault), 100 * 10 ** 18);
        vault.deposit(100 * 10 ** 18);

        // Attempt to withdraw more shares than owned
        vault.withdraw(200 * 10 ** 18); // This should fail
        vm.stopPrank();
    }
}
