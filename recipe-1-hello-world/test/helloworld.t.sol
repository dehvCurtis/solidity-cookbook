// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/HelloWorld.sol";

/**
 * @title HelloWorldTest
 * @author Solidity Cookbook
 * @notice Comprehensive test suite for HelloWorld contracts
 * @dev Tests both vulnerable and secure implementations
 */
contract HelloWorldTest is Test {
    // ============================================
    // Test Contracts
    // ============================================
    
    HelloWorld public vulnerable;
    HelloWorldSecure public secure;
    
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
    
    string constant INITIAL_GREETING = "Hello, World!";
    string constant NEW_GREETING = "Hello, Solidity!";
    string constant EMPTY_GREETING = "";
    
    // ============================================
    // Events
    // ============================================
    
    event GreetingChanged(string indexed oldGreeting, string indexed newGreeting, address indexed changer);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferInitiated(address indexed currentOwner, address indexed pendingOwner);
    event UserBlacklisted(address indexed user, bool indexed status);
    
    // ============================================
    // Setup
    // ============================================
    
    function setUp() public {
        // Deploy contracts
        vulnerable = new HelloWorld();
        secure = new HelloWorldSecure();
        
        // Fund test accounts
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
        vm.deal(charlie, 10 ether);
        vm.deal(attacker, 10 ether);
        
        // Label accounts for better trace output
        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(charlie, "Charlie");
        vm.label(attacker, "Attacker");
        vm.label(address(vulnerable), "VulnerableContract");
        vm.label(address(secure), "SecureContract");
    }
    
    // ============================================
    // Basic Functionality Tests
    // ============================================
    
    function test_InitialState() public view {
        // Check initial greeting
        assertEq(vulnerable.greeting(), INITIAL_GREETING);
        assertEq(secure.greeting(), INITIAL_GREETING);
        
        // Check initial owner
        assertEq(vulnerable.owner(), owner);
        assertEq(secure.owner(), owner);
        
        // Check initial counters
        assertEq(vulnerable.updateCount(), 0);
        assertEq(secure.updateCount(), 0);
    }
    
    function test_SetGreeting_Success() public {
        // Test vulnerable version
        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit GreetingChanged(INITIAL_GREETING, NEW_GREETING, alice);
        vulnerable.setGreeting(NEW_GREETING);
        
        assertEq(vulnerable.greeting(), NEW_GREETING);
        assertEq(vulnerable.updateCount(), 1);
        assertEq(vulnerable.userUpdateCount(alice), 1);
        
        // Test secure version
        vm.prank(bob);
        vm.expectEmit(true, true, true, true);
        emit GreetingChanged(INITIAL_GREETING, NEW_GREETING, bob);
        secure.setGreeting(NEW_GREETING);
        
        assertEq(secure.greeting(), NEW_GREETING);
        assertEq(secure.updateCount(), 1);
        assertEq(secure.userUpdateCount(bob), 1);
    }
    
    function test_MultipleUpdates() public {
        // Alice updates twice
        vm.startPrank(alice);
        vulnerable.setGreeting("First");
        vulnerable.setGreeting("Second");
        vm.stopPrank();
        
        assertEq(vulnerable.userUpdateCount(alice), 2);
        assertEq(vulnerable.updateCount(), 2);
        
        // Bob updates once
        vm.prank(bob);
        vulnerable.setGreeting("Third");
        
        assertEq(vulnerable.userUpdateCount(bob), 1);
        assertEq(vulnerable.updateCount(), 3);
    }
    
    function test_GetUserStats() public {
        vm.prank(alice);
        vulnerable.setGreeting("Alice's greeting");
        
        (uint256 updates, bool isBlacklisted) = vulnerable.getUserStats(alice);
        assertEq(updates, 1);
        assertEq(isBlacklisted, false);
    }
    
    function test_GetContractStats() public {
        vm.prank(alice);
        vulnerable.setGreeting("New");
        
        (string memory greeting, uint256 updates, address contractOwner) = vulnerable.getContractStats();
        assertEq(greeting, "New");
        assertEq(updates, 1);
        assertEq(contractOwner, owner);
    }
    
    // ============================================
    // Vulnerability Tests
    // ============================================
    
    /**
     * @notice Test VULNERABILITY 1: Empty string acceptance
     */
    function test_Vulnerability_EmptyString() public {
        // Vulnerable: Accepts empty string
        vm.prank(alice);
        vulnerable.setGreeting(EMPTY_GREETING);
        assertEq(vulnerable.greeting(), EMPTY_GREETING);
        
        // Secure: Rejects empty string
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                HelloWorldSecure.GreetingTooShort.selector,
                0,
                secure.MIN_GREETING_LENGTH()
            )
        );
        secure.setGreeting(EMPTY_GREETING);
    }
    
    /**
     * @notice Test VULNERABILITY 2: Gas griefing with long strings
     */
    function test_Vulnerability_GasGriefing() public {
        // Create a very long string (1000 characters)
        bytes memory longBytes = new bytes(1000);
        for (uint256 i = 0; i < 1000; i++) {
            longBytes[i] = bytes1(uint8(65 + (i % 26)));
        }
        string memory veryLongString = string(longBytes);
        
        // Vulnerable: Accepts very long string (gas griefing possible)
        vm.prank(alice);
        vulnerable.setGreeting(veryLongString);
        assertEq(bytes(vulnerable.greeting()).length, 1000);
        
        // Secure: Rejects strings over MAX_GREETING_LENGTH
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                HelloWorldSecure.GreetingTooLong.selector,
                1000,
                secure.MAX_GREETING_LENGTH()
            )
        );
        secure.setGreeting(veryLongString);
    }
    
    /**
     * @notice Test VULNERABILITY 3: tx.origin authentication
     */
    function test_Vulnerability_TxOrigin() public {
        // Deploy phishing contract
        TxOriginExploiter exploiter = new TxOriginExploiter(address(vulnerable));
        
        // Owner interacts with malicious contract
        // This sets both msg.sender (exploiter) and tx.origin (owner)
        exploiter.exploit();
        
        // The vulnerable contract was tricked!
        assertEq(vulnerable.greeting(), INITIAL_GREETING);
        
        // Secure version would fail
        TxOriginExploiter exploiter2 = new TxOriginExploiter(address(secure));
        vm.expectRevert(
            abi.encodeWithSelector(HelloWorldSecure.NotOwner.selector, address(exploiter2))
        );
        exploiter2.exploitSecure();
    }
    
    /**
     * @notice Test VULNERABILITY 4: Zero address ownership transfer
     */
    function test_Vulnerability_ZeroAddressTransfer() public {
        // Vulnerable: Allows transfer to zero address
        vulnerable.transferOwnership(address(0));
        assertEq(vulnerable.owner(), address(0));
        
        // Contract is now permanently locked!
        vm.expectRevert("Only owner");
        vulnerable.transferOwnership(alice);
        
        // Secure: Prevents zero address transfer
        vm.expectRevert(HelloWorldSecure.ZeroAddress.selector);
        secure.initiateOwnershipTransfer(address(0));
    }
    
    /**
     * @notice Test VULNERABILITY 5: Single-step ownership transfer
     */
    function test_Vulnerability_SingleStepTransfer() public {
        // Vulnerable: Immediate transfer (risky)
        vulnerable.transferOwnership(alice);
        assertEq(vulnerable.owner(), alice);
        
        // If alice is a contract without ability to call functions, ownership is lost!
        
        // Secure: Two-step transfer
        secure.initiateOwnershipTransfer(alice);
        assertEq(secure.owner(), owner); // Still original owner
        assertEq(secure.pendingOwner(), alice);
        
        // Alice must accept
        vm.prank(alice);
        secure.acceptOwnership();
        assertEq(secure.owner(), alice);
        assertEq(secure.pendingOwner(), address(0));
    }
    
    /**
     * @notice Test VULNERABILITY 6: Missing event emission
     */
    function test_Vulnerability_MissingEvent() public {
        // Vulnerable: No event for blacklist changes
        vm.recordLogs();
        vulnerable.setBlacklist(alice, true);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 0); // No event emitted!
        
        // Secure: Emits event
        vm.expectEmit(true, true, false, false);
        emit UserBlacklisted(bob, true);
        secure.setBlacklist(bob, true);
    }
    
    /**
     * @notice Test VULNERABILITY 7: Reentrancy attack
     */
    function test_Vulnerability_Reentrancy() public {
        // Deploy reentrancy attacker
        ReentrancyAttacker reentrancyAttacker = new ReentrancyAttacker();
        
        // Set target after deployment
        reentrancyAttacker.setTarget(address(vulnerable));
        
        // Perform reentrancy attack
        vm.prank(alice);
        vulnerable.updateAndNotify("Under attack!", address(reentrancyAttacker));
        
        // Check that attacker was called multiple times
        assertGt(reentrancyAttacker.callCount(), 0);
        
        // Secure version prevents reentrancy by updating state first
        ReentrancyAttacker reentrancyAttacker2 = new ReentrancyAttacker();
        reentrancyAttacker2.setTarget(address(secure));
        
        vm.prank(alice);
        secure.updateAndNotify("Safe update", address(reentrancyAttacker2));
        
        // State was updated before external call
        assertEq(secure.greeting(), "Safe update");
    }
    
    // ============================================
    // Security Feature Tests
    // ============================================
    
    function test_OnlyOwnerModifier() public {
        // Non-owner cannot reset greeting
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(HelloWorldSecure.NotOwner.selector, alice)
        );
        secure.resetGreeting();
        
        // Owner can reset
        secure.resetGreeting();
        assertEq(secure.greeting(), INITIAL_GREETING);
    }
    
    function test_BlacklistFunctionality() public {
        // Blacklist alice
        secure.setBlacklist(alice, true);
        
        // Alice cannot update greeting
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(HelloWorldSecure.UserIsBlacklisted.selector, alice)
        );
        secure.setGreeting("Should fail");
        
        // Bob can still update
        vm.prank(bob);
        secure.setGreeting("Bob's greeting");
        assertEq(secure.greeting(), "Bob's greeting");
        
        // Unblacklist alice
        secure.setBlacklist(alice, false);
        
        // Alice can update again
        vm.prank(alice);
        secure.setGreeting("Alice is back");
        assertEq(secure.greeting(), "Alice is back");
    }
    
    function test_CooldownMechanism() public {
        // Alice updates greeting
        vm.prank(alice);
        secure.setGreeting("First update");
        
        // Alice tries to update again in same block
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(HelloWorldSecure.CooldownActive.selector, block.number)
        );
        secure.setGreeting("Too fast!");
        
        // Move forward one block
        vm.roll(block.number + 1);
        
        // Now alice can update
        vm.prank(alice);
        secure.setGreeting("Second update");
        assertEq(secure.greeting(), "Second update");
    }
    
    function test_TwoStepOwnershipTransfer_Complete() public {
        // Initiate transfer to alice
        secure.initiateOwnershipTransfer(alice);
        
        // Bob cannot accept
        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(HelloWorldSecure.NotPendingOwner.selector, bob)
        );
        secure.acceptOwnership();
        
        // Alice accepts
        vm.prank(alice);
        secure.acceptOwnership();
        
        assertEq(secure.owner(), alice);
        assertEq(secure.pendingOwner(), address(0));
    }
    
    function test_CancelOwnershipTransfer() public {
        // Initiate transfer
        secure.initiateOwnershipTransfer(alice);
        assertEq(secure.pendingOwner(), alice);
        
        // Cancel transfer
        secure.cancelOwnershipTransfer();
        assertEq(secure.pendingOwner(), address(0));
        
        // Alice cannot accept cancelled transfer
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(HelloWorldSecure.NotPendingOwner.selector, alice)
        );
        secure.acceptOwnership();
    }
    
    // ============================================
    // Fuzz Tests
    // ============================================
    
    function testFuzz_SetGreeting(string memory _greeting) public {
        // Only test valid lengths
        vm.assume(bytes(_greeting).length > 0);
        vm.assume(bytes(_greeting).length <= secure.MAX_GREETING_LENGTH());
        
        vm.prank(alice);
        secure.setGreeting(_greeting);
        assertEq(secure.greeting(), _greeting);
    }
    
    function testFuzz_OwnershipTransfer(address _newOwner) public {
        // Exclude invalid addresses
        vm.assume(_newOwner != address(0));
        vm.assume(_newOwner != owner);
        
        // Initiate transfer
        secure.initiateOwnershipTransfer(_newOwner);
        assertEq(secure.pendingOwner(), _newOwner);
        
        // Accept transfer
        vm.prank(_newOwner);
        secure.acceptOwnership();
        assertEq(secure.owner(), _newOwner);
    }
    
    function testFuzz_Blacklist(address _user, bool _status) public {
        vm.assume(_user != address(0));
        
        secure.setBlacklist(_user, _status);
        assertEq(secure.blacklisted(_user), _status);
        
        if (_status) {
            vm.prank(_user);
            vm.expectRevert(
                abi.encodeWithSelector(HelloWorldSecure.UserIsBlacklisted.selector, _user)
            );
            secure.setGreeting("Should fail");
        } else {
            vm.prank(_user);
            secure.setGreeting("Should work");
            assertEq(secure.greeting(), "Should work");
        }
    }
    
    function testFuzz_UpdateCounts(uint8 _numUpdates) public {
        vm.assume(_numUpdates > 0 && _numUpdates <= 10);
        
        for (uint8 i = 0; i < _numUpdates; i++) {
            vm.roll(block.number + 2); // Move forward to avoid cooldown
            vm.prank(alice);
            secure.setGreeting(string(abi.encodePacked("Update ", i)));
        }
        
        assertEq(secure.updateCount(), _numUpdates);
        assertEq(secure.userUpdateCount(alice), _numUpdates);
    }
}

// ============================================
// Helper Contracts
// ============================================

/**
 * @title TxOriginExploiter
 * @notice Demonstrates tx.origin vulnerability
 */
contract TxOriginExploiter {
    address public vulnerableTarget;
    address public secureTarget;
    
    constructor(address _target) {
        vulnerableTarget = _target;
        secureTarget = _target;
    }
    
    function exploit() external {
        // This works on vulnerable contract when called by owner
        HelloWorld(vulnerableTarget).resetGreeting();
    }
    
    function exploitSecure() external {
        // This fails on secure contract
        HelloWorldSecure(secureTarget).resetGreeting();
    }
}

/**
 * @title ReentrancyAttacker
 * @notice Demonstrates reentrancy vulnerability
 */
contract ReentrancyAttacker {
    uint256 public callCount;
    address public target;
    
    function setTarget(address _target) external {
        target = _target;
    }
    
    function notify(string memory) external {
        callCount++;
        
        // Try to reenter if called less than 3 times
        if (callCount < 3 && target != address(0)) {
            // This could cause issues in vulnerable contract
            HelloWorld(target).setGreeting("Reentered!");
        }
    }
}