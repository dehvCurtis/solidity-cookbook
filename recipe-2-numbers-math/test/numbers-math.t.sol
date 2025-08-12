// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "src/numbers-math.sol";

/**
 * @title NumbersAndMathTest
 * @author Solidity Cookbook
 * @notice Comprehensive test suite for arithmetic operations
 * @dev Tests both vulnerable and secure implementations
 */
contract NumbersAndMathTest is Test {
    // ============================================
    // Test Contracts
    // ============================================
    
    NumbersAndMath public vulnerable;
    NumbersAndMathSecure public secure;
    
    // ============================================
    // Test Accounts
    // ============================================
    
    address public owner = address(this);
    address public alice = address(0x1);
    address public bob = address(0x2);
    address public charlie = address(0x3);
    address public attacker = address(0x666);
    
    // ============================================
    // Test Constants
    // ============================================
    
    uint256 constant INITIAL_SUPPLY = 1000000 * 10**18;
    uint256 constant TEST_AMOUNT = 1000 * 10**18;
    uint256 constant SMALL_AMOUNT = 100; // Less than fee threshold
    uint256 constant PRECISION = 1e18;
    
    // ============================================
    // Events
    // ============================================
    
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Staked(address indexed user, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 amount);
    
    // ============================================
    // Setup
    // ============================================
    
    function setUp() public {
        // Deploy contracts
        vulnerable = new NumbersAndMath();
        secure = new NumbersAndMathSecure();
        
        // Fund test accounts
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
        vm.deal(charlie, 10 ether);
        vm.deal(attacker, 10 ether);
        
        // Label accounts
        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(charlie, "Charlie");
        vm.label(attacker, "Attacker");
        vm.label(address(vulnerable), "VulnerableContract");
        vm.label(address(secure), "SecureContract");
        
        // Give some tokens to test accounts
        vulnerable.transfer(alice, TEST_AMOUNT);
        vulnerable.transfer(bob, TEST_AMOUNT);
        
        secure.transfer(alice, TEST_AMOUNT);
        secure.transfer(bob, TEST_AMOUNT);
    }
    
    // ============================================
    // Basic Functionality Tests
    // ============================================
    
    function test_InitialState() public view {
        // Check initial supply
        assertEq(vulnerable.totalSupply(), INITIAL_SUPPLY);
        assertEq(secure.totalSupply(), INITIAL_SUPPLY);
        
        // Check owner balance
        assertEq(vulnerable.balances(owner), INITIAL_SUPPLY - 2 * TEST_AMOUNT);
        assertEq(secure.balances(owner), INITIAL_SUPPLY - 2 * TEST_AMOUNT);
        
        // Check test account balances
        assertEq(vulnerable.balances(alice), TEST_AMOUNT);
        assertEq(secure.balances(alice), TEST_AMOUNT);
    }
    
    function test_BasicTransfer() public {
        uint256 transferAmount = 100 * 10**18;
        
        // Vulnerable transfer
        vm.prank(alice);
        assertTrue(vulnerable.transfer(charlie, transferAmount));
        assertEq(vulnerable.balances(alice), TEST_AMOUNT - transferAmount);
        assertEq(vulnerable.balances(charlie), transferAmount);
        
        // Secure transfer
        vm.prank(alice);
        assertTrue(secure.transfer(charlie, transferAmount));
        assertEq(secure.balances(alice), TEST_AMOUNT - transferAmount);
        assertEq(secure.balances(charlie), transferAmount);
    }
    
    function test_TransferWithFee() public {
        uint256 transferAmount = 100 * 10**18;
        uint256 expectedFee = (transferAmount * 300) / 10000; // 3%
        uint256 expectedReceived = transferAmount - expectedFee;
        
        // Test secure version
        uint256 aliceBalanceBefore = secure.balances(alice);
        uint256 ownerBalanceBefore = secure.balances(owner);
        
        vm.prank(alice);
        assertTrue(secure.transferWithFee(charlie, transferAmount));
        
        assertEq(secure.balances(alice), aliceBalanceBefore - transferAmount);
        assertEq(secure.balances(charlie), expectedReceived);
        assertEq(secure.balances(owner), ownerBalanceBefore + expectedFee);
    }
    
    function test_StakingBasic() public {
        uint256 stakeAmount = 100 * 10**18;
        
        // Stake tokens
        vm.prank(alice);
        secure.stake(stakeAmount);
        
        assertEq(secure.stakedAmount(alice), stakeAmount);
        assertEq(secure.totalStaked(), stakeAmount);
        assertEq(secure.balances(alice), TEST_AMOUNT - stakeAmount);
        
        // Unstake tokens
        vm.prank(alice);
        secure.unstake(stakeAmount);
        
        assertEq(secure.stakedAmount(alice), 0);
        assertEq(secure.totalStaked(), 0);
        assertEq(secure.balances(alice), TEST_AMOUNT);
    }
    
    // ============================================
    // Vulnerability Tests
    // ============================================
    
    /**
     * @notice Test VULNERABILITY 1 & 2: Overflow/Underflow
     */
    function test_Vulnerability_OverflowUnderflow() public {
        // In Solidity 0.8+, these automatically revert
        // Testing underflow
        vm.prank(alice);
        vm.expectRevert(); // Arithmetic underflow
        vulnerable.transfer(bob, TEST_AMOUNT + 1);
        
        // Secure version has explicit checks
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                NumbersAndMathSecure.InsufficientBalance.selector,
                TEST_AMOUNT + 1,
                TEST_AMOUNT
            )
        );
        secure.transfer(bob, TEST_AMOUNT + 1);
    }
    
    /**
     * @notice Test VULNERABILITY 3: Precision loss in fee calculation
     */
    function test_Vulnerability_PrecisionLoss() public view {
        uint256 amount = 10000;
        
        // Vulnerable: wrong order of operations
        uint256 vulnerableFee = vulnerable.calculateFee(amount);
        // amount / BASIS_POINTS * feePercentage = 10000 / 10000 * 300 = 1 * 300 = 300
        assertEq(vulnerableFee, 300);
        
        // Secure: correct order
        uint256 secureFee = secure.calculateFee(amount);
        // (amount * feePercentage) / BASIS_POINTS = (10000 * 300) / 10000 = 300
        assertEq(secureFee, 300);
        
        // Test with amount that shows the difference
        uint256 smallAmount = 9999;
        
        // Vulnerable: 9999 / 10000 * 300 = 0 * 300 = 0 (WRONG!)
        vulnerableFee = vulnerable.calculateFee(smallAmount);
        assertEq(vulnerableFee, 0);
        
        // Secure: (9999 * 300) / 10000 = 2999700 / 10000 = 299 (CORRECT)
        secureFee = secure.calculateFee(smallAmount);
        assertEq(secureFee, 299);
    }
    
    /**
     * @notice Test VULNERABILITY 4: Rounding errors accumulation
     */
    function test_Vulnerability_RoundingErrors() public {
        // Transfer very small amount where fee rounds to 0
        uint256 dustAmount = 10;
        
        // Vulnerable: Fee is 0 for small amounts
        uint256 fee = vulnerable.calculateFee(dustAmount);
        assertEq(fee, 0); // No fee collected!
        
        // Multiple small transfers could avoid fees entirely
        for (uint256 i = 0; i < 10; i++) {
            vm.prank(alice);
            vulnerable.transferWithFee(bob, dustAmount);
        }
        
        // Secure version has minimum amount check
        vm.prank(alice);
        vm.expectRevert("Amount too small after fee");
        secure.transferWithFee(bob, dustAmount);
    }
    
    /**
     * @notice Test VULNERABILITY 5: Approval front-running
     */
    function test_Vulnerability_ApprovalFrontRunning() public {
        // Alice approves Bob for 100 tokens
        vm.prank(alice);
        vulnerable.approve(bob, 100 * 10**18);
        
        // Alice wants to change approval to 200
        // Bob could front-run and spend 100 first, then get 200 more
        // Total: 300 instead of intended 200
        
        // Secure version prevents this
        vm.prank(alice);
        secure.approve(bob, 100 * 10**18);
        
        // Must set to 0 first or use increase/decrease
        vm.prank(alice);
        vm.expectRevert("Use increaseAllowance or decreaseAllowance");
        secure.approve(bob, 200 * 10**18);
        
        // Correct way
        vm.prank(alice);
        secure.increaseAllowance(bob, 100 * 10**18);
        assertEq(secure.allowances(alice, bob), 200 * 10**18);
    }
    
    /**
     * @notice Test VULNERABILITY 6: Reward calculation without update
     */
    function test_Vulnerability_StakingRewardUpdate() public {
        uint256 stakeAmount = 100 * 10**18;
        
        // Alice stakes
        vm.prank(alice);
        vulnerable.stake(stakeAmount);
        
        // Mine some blocks
        vm.roll(block.number + 10);
        
        // Bob stakes - rewards not updated first in vulnerable version
        vm.prank(bob);
        vulnerable.stake(stakeAmount);
        
        // In vulnerable contract, Bob might get unfair share of rewards
        // because rewards weren't distributed before his stake
        
        // Secure version always updates rewards first
        vm.prank(alice);
        secure.stake(stakeAmount);
        
        vm.roll(block.number + 10);
        
        uint256 alicePendingBefore = secure.pendingReward(alice);
        assertGt(alicePendingBefore, 0);
        
        vm.prank(bob);
        secure.stake(stakeAmount);
        
        // Alice's pending rewards are preserved
        uint256 alicePendingAfter = secure.pendingReward(alice);
        assertGe(alicePendingAfter, alicePendingBefore);
    }
    
    /**
     * @notice Test VULNERABILITY 7: Division before multiplication
     */
    function test_Vulnerability_DivisionBeforeMultiplication() public {
        // Stake small amount
        uint256 smallStake = 100;
        vm.prank(alice);
        vulnerable.stake(TEST_AMOUNT); // Need some total supply
        
        vm.prank(bob);
        vulnerable.stake(smallStake);
        
        // Calculate rewards - vulnerable version
        uint256 vulnerableReward = vulnerable.calculateRewards(bob);
        // smallStake / totalSupply * blocks * rate
        // 100 / 1000000e18 * blocks * 100 = 0 (precision lost!)
        assertEq(vulnerableReward, 0);
        
        // Secure version uses accumulator pattern with precision
        vm.prank(alice);
        secure.stake(TEST_AMOUNT);
        
        vm.prank(bob);
        secure.stake(smallStake);
        
        vm.roll(block.number + 10);
        
        uint256 secureReward = secure.pendingReward(bob);
        assertGt(secureReward, 0); // Properly calculated with precision
    }
    
    /**
     * @notice Test VULNERABILITY 8: Overflow in value calculation
     */
    function test_Vulnerability_ValueCalculationOverflow() public view {
        uint256 largeAmount = type(uint256).max / 2;
        
        // Vulnerable: might overflow
        unchecked {
            // This would overflow without unchecked block
            // We don't use the value, just demonstrating it computes without reverting
            vulnerable.getValueInUSD(largeAmount);
        }
        
        // Secure: proper decimal handling prevents overflow
        uint256 secureValue = secure.getValueInUSD(1000 * 10**18);
        // (1000e18 * 1e6) / 1e18 = 1000e6 (correct USD value)
        assertEq(secureValue, 1000 * 10**6);
    }
    
    /**
     * @notice Test VULNERABILITY 9: No price validation
     */
    function test_Vulnerability_PriceManipulation() public {
        // Vulnerable: anyone can set any price
        vm.prank(attacker);
        vulnerable.updatePrice(0);
        assertEq(vulnerable.tokenPrice(), 0);
        
        vm.prank(attacker);
        vulnerable.updatePrice(type(uint256).max);
        assertEq(vulnerable.tokenPrice(), type(uint256).max);
        
        // Secure: only oracle can update, with bounds
        vm.prank(attacker);
        vm.expectRevert(NumbersAndMathSecure.Unauthorized.selector);
        secure.updatePrice(2000000);
        
        // Even oracle cannot set invalid price
        vm.prank(owner); // Owner is initial oracle
        vm.expectRevert(
            abi.encodeWithSelector(
                NumbersAndMathSecure.InvalidPrice.selector,
                0
            )
        );
        secure.updatePrice(0);
    }
    
    /**
     * @notice Test VULNERABILITY 10: Dust in division
     */
    function test_Vulnerability_DivisionDust() public {
        address[] memory recipients = new address[](3);
        recipients[0] = alice;
        recipients[1] = bob;
        recipients[2] = charlie;
        
        // Give owner 100 tokens
        vulnerable.transfer(owner, 100);
        
        uint256 ownerBalance = vulnerable.balances(owner);
        vm.prank(owner);
        vulnerable.divideBalance(recipients);
        
        // 100 / 3 = 33, remainder = 1
        assertEq(vulnerable.balances(alice), TEST_AMOUNT + 33);
        assertEq(vulnerable.balances(bob), TEST_AMOUNT + 33);
        assertEq(vulnerable.balances(charlie), 33);
        assertEq(vulnerable.balances(owner), ownerBalance - 99); // 1 dust remains!
        
        // Secure version handles dust
        secure.transfer(owner, 100);
        uint256 secureOwnerBalance = secure.balances(owner);
        
        vm.prank(owner);
        secure.divideBalance(recipients);
        
        assertEq(secure.balances(alice), TEST_AMOUNT + 33);
        assertEq(secure.balances(bob), TEST_AMOUNT + 33);
        assertEq(secure.balances(charlie), 34); // Gets the dust
        assertEq(secure.balances(owner), secureOwnerBalance - 100); // No dust remains
    }
    
    /**
     * @notice Test VULNERABILITY 11: Division by zero
     */
    function test_Vulnerability_DivisionByZero() public {
        // Vulnerable: will panic
        vm.expectRevert(); // Division by zero panic
        vulnerable.calculatePercentage(100, 0);
        
        // Secure: clean revert
        vm.expectRevert(NumbersAndMathSecure.DivisionByZero.selector);
        secure.calculatePercentage(100, 0);
    }
    
    // ============================================
    // Security Feature Tests
    // ============================================
    
    function test_PrecisionHandling() public view {
        // Test precise percentage calculation
        uint256 value = 333;
        uint256 total = 1000;
        
        // Basic calculation: 33%
        uint256 percentage = secure.calculatePercentage(value, total);
        assertEq(percentage, 33);
        
        // Precise calculation: 33.3% with 18 decimals
        uint256 precisePct = secure.calculatePercentagePrecise(value, total);
        assertEq(precisePct, 33.3e18);
    }
    
    function test_RewardAccumulation() public {
        uint256 stakeAmount = 100 * 10**18;
        
        // Alice stakes
        vm.prank(alice);
        secure.stake(stakeAmount);
        
        // Mine 10 blocks
        vm.roll(block.number + 10);
        
        // Check pending rewards
        uint256 pending = secure.pendingReward(alice);
        assertGt(pending, 0);
        
        // Claim rewards
        vm.prank(alice);
        secure.claimRewards();
        
        // Rewards added to balance
        assertGt(secure.balances(alice), TEST_AMOUNT - stakeAmount);
        
        // No pending rewards after claim
        assertEq(secure.pendingReward(alice), 0);
    }
    
    function test_PriceOracleAccess() public {
        address newOracle = address(0x999);
        
        // Set new oracle
        secure.setPriceOracle(newOracle);
        
        // New oracle can update price
        vm.prank(newOracle);
        secure.updatePrice(2000000); // $2
        assertEq(secure.tokenPrice(), 2000000);
        
        // Old oracle cannot
        vm.prank(owner);
        vm.expectRevert(NumbersAndMathSecure.Unauthorized.selector);
        secure.updatePrice(3000000);
    }
    
    function test_FeeConfiguration() public {
        // Set new fee
        uint256 newFee = 500; // 5%
        secure.setFeePercentage(newFee);
        assertEq(secure.feePercentage(), newFee);
        
        // Cannot set fee above maximum
        vm.expectRevert(
            abi.encodeWithSelector(
                NumbersAndMathSecure.FeeExceedsMaximum.selector,
                1001
            )
        );
        secure.setFeePercentage(1001);
    }
    
    // ============================================
    // Fuzz Tests
    // ============================================
    
    function testFuzz_Transfer(address to, uint256 amount) public {
        vm.assume(to != address(0));
        vm.assume(amount > 0 && amount <= TEST_AMOUNT);
        
        uint256 aliceBalanceBefore = secure.balances(alice);
        
        vm.prank(alice);
        secure.transfer(to, amount);
        
        assertEq(secure.balances(alice), aliceBalanceBefore - amount);
        assertEq(secure.balances(to), amount);
    }
    
    function testFuzz_FeeCalculation(uint256 amount) public view {
        vm.assume(amount < type(uint256).max / secure.feePercentage());
        
        uint256 fee = secure.calculateFee(amount);
        uint256 expected = (amount * secure.feePercentage()) / secure.BASIS_POINTS();
        
        assertEq(fee, expected);
        
        // Fee should never exceed amount
        assertLe(fee, amount);
    }
    
    function testFuzz_Staking(uint256 stakeAmount) public {
        vm.assume(stakeAmount > 0 && stakeAmount <= TEST_AMOUNT);
        
        uint256 balanceBefore = secure.balances(alice);
        
        vm.prank(alice);
        secure.stake(stakeAmount);
        
        assertEq(secure.stakedAmount(alice), stakeAmount);
        assertEq(secure.balances(alice), balanceBefore - stakeAmount);
        
        vm.prank(alice);
        secure.unstake(stakeAmount);
        
        assertEq(secure.stakedAmount(alice), 0);
        assertEq(secure.balances(alice), balanceBefore);
    }
    
    function testFuzz_Percentage(uint256 value, uint256 total) public view {
        vm.assume(total > 0);
        vm.assume(value <= total);
        
        uint256 percentage = secure.calculatePercentage(value, total);
        
        assertLe(percentage, 100);
        
        if (value == total) {
            assertEq(percentage, 100);
        } else if (value == 0) {
            assertEq(percentage, 0);
        }
    }
    
    function testFuzz_PriceUpdate(uint256 price) public {
        vm.assume(price >= secure.MIN_PRICE());
        vm.assume(price <= secure.MAX_PRICE());
        
        vm.prank(owner); // Owner is oracle
        secure.updatePrice(price);
        
        assertEq(secure.tokenPrice(), price);
    }
}

// ============================================
// Helper Contracts
// ============================================

/**
 * @title MaliciousApprover
 * @notice Demonstrates approval front-running
 */
contract MaliciousApprover {
    NumbersAndMath public target;
    
    constructor(address _target) {
        target = NumbersAndMath(_target);
    }
    
    function frontRun(address victim, address spender) external {
        // In a real attack, this would be triggered when seeing
        // a pending approval transaction in the mempool
        // The attacker would quickly spend the current allowance
        // before the new approval is mined
    }
}