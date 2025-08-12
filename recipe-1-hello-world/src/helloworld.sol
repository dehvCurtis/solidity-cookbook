// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title HelloWorld
 * @author Solidity Cookbook
 * @notice Vulnerable version with intentional security issues for learning
 * @dev This contract demonstrates common vulnerabilities in state management
 */
contract HelloWorld {
    // ============================================
    // State Variables
    // ============================================
    
    string public greeting;
    address public owner;
    uint256 public updateCount;
    mapping(address => uint256) public userUpdateCount;
    mapping(address => bool) public blacklisted;
    
    // ============================================
    // Events
    // ============================================
    
    event GreetingChanged(string indexed oldGreeting, string indexed newGreeting, address indexed changer);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event UserBlacklisted(address indexed user, bool status);
    
    // ============================================
    // Constructor
    // ============================================
    
    constructor() {
        greeting = "Hello, World!";
        owner = msg.sender;
    }
    
    // ============================================
    // Core Functions
    // ============================================
    
    /**
     * @notice Updates the greeting message
     * @dev VULNERABILITY 1: No input validation - accepts empty strings
     * @dev VULNERABILITY 2: No length limit - gas griefing possible
     * @param _newGreeting The new greeting message
     */
    function setGreeting(string memory _newGreeting) external {
        // VULNERABILITY 1 & 2: Missing input validation
        string memory oldGreeting = greeting;
        greeting = _newGreeting;
        updateCount++;
        userUpdateCount[msg.sender]++;
        
        emit GreetingChanged(oldGreeting, _newGreeting, msg.sender);
    }
    
    /**
     * @notice Resets greeting to default
     * @dev VULNERABILITY 3: Uses tx.origin for authentication (phishing risk)
     */
    function resetGreeting() external {
        // VULNERABILITY 3: tx.origin can be exploited
        require(tx.origin == owner, "Only owner can reset");
        greeting = "Hello, World!";
        updateCount++;
    }
    
    /**
     * @notice Transfer ownership in one step
     * @dev VULNERABILITY 4: No zero address check
     * @dev VULNERABILITY 5: Single-step transfer (can lose ownership)
     * @param newOwner Address of new owner
     */
    function transferOwnership(address newOwner) external {
        require(msg.sender == owner, "Only owner");
        // VULNERABILITY 4: Missing zero address check
        // VULNERABILITY 5: No confirmation from new owner
        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
    
    /**
     * @notice Blacklist a user from updating greeting
     * @dev VULNERABILITY 6: No event emission for state change
     * @param user Address to blacklist
     * @param status Blacklist status
     */
    function setBlacklist(address user, bool status) external {
        require(msg.sender == owner, "Only owner");
        // VULNERABILITY 6: Missing event emission
        blacklisted[user] = status;
    }
    
    /**
     * @notice Update greeting and notify external contract
     * @dev VULNERABILITY 7: Reentrancy - state change after external call
     * @param _newGreeting New greeting message
     * @param notifyAddress Contract to notify
     */
    function updateAndNotify(string memory _newGreeting, address notifyAddress) external {
        require(!blacklisted[msg.sender], "User blacklisted");
        
        // VULNERABILITY 7: External call before state change
        (bool success, ) = notifyAddress.call(
            abi.encodeWithSignature("notify(string)", _newGreeting)
        );
        
        // State changes after external call - reentrancy risk
        if (success) {
            string memory oldGreeting = greeting;
            greeting = _newGreeting;
            updateCount++;
            userUpdateCount[msg.sender]++;
            emit GreetingChanged(oldGreeting, _newGreeting, msg.sender);
        }
    }
    
    /**
     * @notice Get user statistics
     * @param user Address to query
     * @return updates Number of updates by user
     * @return isBlacklisted Whether user is blacklisted
     */
    function getUserStats(address user) external view returns (
        uint256 updates,
        bool isBlacklisted
    ) {
        return (userUpdateCount[user], blacklisted[user]);
    }
    
    /**
     * @notice Get contract statistics
     * @return currentGreeting Current greeting message
     * @return totalUpdates Total number of updates
     * @return contractOwner Current owner address
     */
    function getContractStats() external view returns (
        string memory currentGreeting,
        uint256 totalUpdates,
        address contractOwner
    ) {
        return (greeting, updateCount, owner);
    }
}

/**
 * @title HelloWorldSecure
 * @author Solidity Cookbook
 * @notice Secure version with all vulnerabilities fixed
 * @dev Implements security best practices for state management
 */
contract HelloWorldSecure {
    // ============================================
    // State Variables
    // ============================================
    
    string public greeting;
    address public owner;
    address public pendingOwner;
    uint256 public updateCount;
    uint256 public lastUpdateBlock;
    
    mapping(address => uint256) public userUpdateCount;
    mapping(address => bool) public blacklisted;
    mapping(address => uint256) public lastUserUpdate;
    
    // ============================================
    // Constants
    // ============================================
    
    uint256 public constant MAX_GREETING_LENGTH = 280;  // Twitter-like limit
    uint256 public constant MIN_GREETING_LENGTH = 1;
    uint256 public constant UPDATE_COOLDOWN = 1;  // blocks
    
    // ============================================
    // Events
    // ============================================
    
    event GreetingChanged(string indexed oldGreeting, string indexed newGreeting, address indexed changer);
    event OwnershipTransferInitiated(address indexed currentOwner, address indexed pendingOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event UserBlacklisted(address indexed user, bool indexed status);
    
    // ============================================
    // Errors (Gas Efficient)
    // ============================================
    
    error GreetingTooLong(uint256 provided, uint256 maximum);
    error GreetingTooShort(uint256 provided, uint256 minimum);
    error NotOwner(address caller);
    error NotPendingOwner(address caller);
    error ZeroAddress();
    error UserIsBlacklisted(address user);
    error CooldownActive(uint256 blockNumber);
    error SameValue();
    
    // ============================================
    // Modifiers
    // ============================================
    
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner(msg.sender);
        _;
    }
    
    modifier notBlacklisted() {
        if (blacklisted[msg.sender]) revert UserIsBlacklisted(msg.sender);
        _;
    }
    
    modifier validGreeting(string memory _greeting) {
        uint256 length = bytes(_greeting).length;
        if (length > MAX_GREETING_LENGTH) {
            revert GreetingTooLong(length, MAX_GREETING_LENGTH);
        }
        if (length < MIN_GREETING_LENGTH) {
            revert GreetingTooShort(length, MIN_GREETING_LENGTH);
        }
        _;
    }
    
    modifier cooldownCheck() {
        if (lastUserUpdate[msg.sender] >= block.number) {
            revert CooldownActive(block.number);
        }
        _;
    }
    
    // ============================================
    // Constructor
    // ============================================
    
    constructor() {
        greeting = "Hello, World!";
        owner = msg.sender;
        lastUpdateBlock = block.number;
    }
    
    // ============================================
    // Core Functions
    // ============================================
    
    /**
     * @notice Updates the greeting message with validation
     * @dev FIX 1: Input validation for empty strings
     * @dev FIX 2: Length limit to prevent gas griefing
     * @param _newGreeting The new greeting message
     */
    function setGreeting(string memory _newGreeting) 
        external 
        notBlacklisted
        validGreeting(_newGreeting)
        cooldownCheck
    {
        string memory oldGreeting = greeting;
        
        // FIX 1 & 2: Validation through modifiers
        greeting = _newGreeting;
        updateCount++;
        userUpdateCount[msg.sender]++;
        lastUserUpdate[msg.sender] = block.number + UPDATE_COOLDOWN;
        lastUpdateBlock = block.number;
        
        emit GreetingChanged(oldGreeting, _newGreeting, msg.sender);
    }
    
    /**
     * @notice Resets greeting to default (only owner)
     * @dev FIX 3: Uses msg.sender instead of tx.origin
     */
    function resetGreeting() external onlyOwner {
        // FIX 3: msg.sender is secure against phishing
        string memory oldGreeting = greeting;
        greeting = "Hello, World!";
        updateCount++;
        lastUpdateBlock = block.number;
        
        emit GreetingChanged(oldGreeting, "Hello, World!", msg.sender);
    }
    
    /**
     * @notice Initiates ownership transfer (step 1 of 2)
     * @dev FIX 4: Zero address check
     * @dev FIX 5: Two-step transfer pattern
     * @param _pendingOwner Address of pending new owner
     */
    function initiateOwnershipTransfer(address _pendingOwner) external onlyOwner {
        // FIX 4: Zero address check
        if (_pendingOwner == address(0)) revert ZeroAddress();
        if (_pendingOwner == owner) revert SameValue();
        
        // FIX 5: Two-step transfer pattern
        pendingOwner = _pendingOwner;
        emit OwnershipTransferInitiated(owner, _pendingOwner);
    }
    
    /**
     * @notice Completes ownership transfer (step 2 of 2)
     * @dev New owner must call this to accept ownership
     */
    function acceptOwnership() external {
        if (msg.sender != pendingOwner) revert NotPendingOwner(msg.sender);
        
        address previousOwner = owner;
        owner = pendingOwner;
        pendingOwner = address(0);
        
        emit OwnershipTransferred(previousOwner, owner);
    }
    
    /**
     * @notice Cancel pending ownership transfer
     * @dev Only current owner can cancel
     */
    function cancelOwnershipTransfer() external onlyOwner {
        pendingOwner = address(0);
        emit OwnershipTransferInitiated(owner, address(0));
    }
    
    /**
     * @notice Blacklist or unblacklist a user
     * @dev FIX 6: Emits event for state change
     * @param user Address to update
     * @param status New blacklist status
     */
    function setBlacklist(address user, bool status) external onlyOwner {
        if (user == address(0)) revert ZeroAddress();
        if (blacklisted[user] == status) revert SameValue();
        
        // FIX 6: Event emission for tracking
        blacklisted[user] = status;
        emit UserBlacklisted(user, status);
    }
    
    /**
     * @notice Update greeting and notify external contract
     * @dev FIX 7: Follows checks-effects-interactions pattern
     * @param _newGreeting New greeting message
     * @param notifyAddress Contract to notify (use address(0) to skip)
     */
    function updateAndNotify(string memory _newGreeting, address notifyAddress) 
        external 
        notBlacklisted
        validGreeting(_newGreeting)
        cooldownCheck
    {
        // FIX 7: All state changes BEFORE external call
        string memory oldGreeting = greeting;
        greeting = _newGreeting;
        updateCount++;
        userUpdateCount[msg.sender]++;
        lastUserUpdate[msg.sender] = block.number + UPDATE_COOLDOWN;
        lastUpdateBlock = block.number;
        
        emit GreetingChanged(oldGreeting, _newGreeting, msg.sender);
        
        // External call AFTER all state changes
        if (notifyAddress != address(0)) {
            // We don't care if this fails - notification is best effort
            // Using low-level call to prevent revert
            // Return value intentionally ignored for best-effort notification
            (bool success, ) = notifyAddress.call{gas: 50000}(
                abi.encodeWithSignature("notify(string)", _newGreeting)
            );
            // Explicitly ignore success to suppress warning
            success; // unused
        }
    }
    
    /**
     * @notice Get user statistics
     * @param user Address to query
     * @return updates Number of updates by user
     * @return isBlacklisted Whether user is blacklisted
     * @return lastUpdate Block number of last update
     */
    function getUserStats(address user) external view returns (
        uint256 updates,
        bool isBlacklisted,
        uint256 lastUpdate
    ) {
        return (
            userUpdateCount[user], 
            blacklisted[user],
            lastUserUpdate[user]
        );
    }
    
    /**
     * @notice Get contract statistics
     * @return currentGreeting Current greeting message
     * @return totalUpdates Total number of updates
     * @return contractOwner Current owner address
     * @return lastBlock Block number of last update
     */
    function getContractStats() external view returns (
        string memory currentGreeting,
        uint256 totalUpdates,
        address contractOwner,
        uint256 lastBlock
    ) {
        return (greeting, updateCount, owner, lastUpdateBlock);
    }
}