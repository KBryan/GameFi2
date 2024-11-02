// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol"; // Adding Ownable for admin control

contract GameFiVault is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    IERC20 public gameToken; // In-game currency (ERC-20 token)
    uint256 public totalShares; // Total shares in the vault
    uint256 public vaultBalance; // Total balance in the vault (tracked in game tokens)

    struct StakerInfo {
        uint256 shares; // The number of shares owned by the user
        uint256 depositTimestamp; // The timestamp of the last deposit
        uint256 accumulatedYield; // Accumulated yield from staking
    }

    mapping(address => StakerInfo) public stakers; // Maps users to their staking info

    event Deposit(address indexed user, uint256 amountDeposited, uint256 sharesMinted);
    event Withdrawal(address indexed user, uint256 amountWithdrawn, uint256 sharesBurned);
    event YieldPaid(address indexed user, uint256 yieldAmount);

    // Constructor to initialize the contract with the game token and call the Ownable constructor
    constructor(IERC20 _gameToken) Ownable(msg.sender) {
        gameToken = _gameToken; // Assign the in-game currency
    }

    // Function to deposit tokens and mint shares
    // Function to deposit tokens and mint shares
    function deposit(uint256 amount) public nonReentrant {
        require(amount > 0, "Deposit amount must be greater than zero");

        // Safely transfer tokens from the user to the contract
        gameToken.safeTransferFrom(msg.sender, address(this), amount);

        // Calculate shares to mint using the equation
        uint256 sharesMinted = (totalShares == 0 || vaultBalance == 0) ? amount : (amount * totalShares) / vaultBalance;
        require(sharesMinted > 0, "Calculated shares must be greater than zero");

        // Update contract state
        totalShares += sharesMinted;
        vaultBalance += amount;

        StakerInfo storage staker = stakers[msg.sender];
        if (staker.shares > 0) {
            // Accumulate yield up to this point before adding new shares
            staker.accumulatedYield += _calculateYield(msg.sender);
        }
        staker.shares += sharesMinted;
        staker.depositTimestamp = block.timestamp;

        emit Deposit(msg.sender, amount, sharesMinted);
    }

    // Internal function to calculate yield
    function _calculateYield(address user) internal view returns (uint256) {
        StakerInfo storage staker = stakers[user];
        if (staker.shares == 0 || staker.depositTimestamp == 0) {
            return 0;
        }

        uint256 stakingDuration = block.timestamp - staker.depositTimestamp;
        uint256 annualYieldRate = 10; // 10% annual yield rate

        // Improved precision by rearranging multiplications
        uint256 yield = (staker.shares * annualYieldRate * stakingDuration) / (365 days * 100);

        return yield + staker.accumulatedYield;
    }

    // Add this function to GameFiVault for testing purposes
    function calculateYieldForUser(address user) public view returns (uint256) {
        return _calculateYield(user);
    }

    function withdraw(uint256 shares) public nonReentrant {
        require(shares > 0, "Shares to withdraw must be greater than zero");
        StakerInfo storage staker = stakers[msg.sender];
        require(staker.shares >= shares, "Insufficient shares to withdraw");

        uint256 amountToWithdraw = (shares * vaultBalance) / totalShares;
        uint256 yield = _calculateYield(msg.sender);

        // Get the actual token balance of the contract
        uint256 actualBalance = gameToken.balanceOf(address(this));
        require(actualBalance >= amountToWithdraw + yield, "Insufficient vault balance for withdrawal");

        // Update contract state before transferring funds
        totalShares -= shares;
        vaultBalance -= amountToWithdraw; // Deduct only the principal amount
        staker.shares -= shares;
        staker.accumulatedYield = 0; // Reset accumulated yield after withdrawal

        if (staker.shares == 0) {
            staker.depositTimestamp = 0; // Clear timestamp if no shares remain
        }

        // Safely transfer tokens to the user
        gameToken.safeTransfer(msg.sender, amountToWithdraw + yield);

        emit Withdrawal(msg.sender, amountToWithdraw, shares);
        emit YieldPaid(msg.sender, yield);
    }
}
