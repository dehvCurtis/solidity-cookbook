// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title NumbersAndMath
 * @author Solidity Cookbook
 * @notice Vulnerable version with intentional arithmetic issues for learning
 * @dev Demonstrates common mathematical vulnerabilities in smart contracts
 */
contract NumbersAndMath {
    // ============================================
    // State Variables
    // ============================================
    
    // Token-like functionality
    mapping(address => uint256) public balances;
    mapping(address => mapping(address => uint256)) public allowances;
    uint256 public totalSupply;
    
    // Staking rewards system
    mapping(address => uint256) public stakedAmount;
    mapping(address => uint256) public rewardDebt;
    uint256 public rewardPerToken;
    uint256 public lastRewardBlock;
    uint256 public constant REWARD_RATE = 100; // tokens per block
    
    // Price oracle simulation
    uint256 public tokenPrice = 1000000; // $1 with 6 decimals
    uint256 public constant PRICE_DECIMALS = 6;
    
    // Fee system
    uint256 public feePercentage = 300; // 3% = 300 basis points
    uint256 public constant BASIS_POINTS = 10000;
    
    // Owner
    address public owner;
    
    // ============================================
    // Events
    // ============================================
    
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event Staked(address indexed user, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 amount);
    event PriceUpdated(uint256 oldPrice, uint256 newPrice);
    
    // ============================================
    // Constructor
    // ============================================
    
    constructor() {
        owner = msg.sender;
        totalSupply = 1000000 * 10**18; // 1 million tokens
        balances[msg.sender] = totalSupply;
        lastRewardBlock = block.number;
    }
    
    // ============================================
    // Token Functions
    // ============================================
    
    /**
     * @notice Transfer tokens
     * @dev VULNERABILITY 1: No overflow check in balance addition (pre-0.8 style)
     * @dev VULNERABILITY 2: No underflow check in balance subtraction
     */
    function transfer(address to, uint256 amount) external returns (bool) {
        // VULNERABILITY 2: Could underflow in Solidity < 0.8
        balances[msg.sender] -= amount;
        
        // VULNERABILITY 1: Could overflow in Solidity < 0.8
        unchecked {
            balances[to] += amount; // Simulating pre-0.8 behavior
        }
        
        emit Transfer(msg.sender, to, amount);
        return true;
    }
    
    /**
     * @notice Calculate fee with division
     * @dev VULNERABILITY 3: Precision loss due to integer division
     */
    function calculateFee(uint256 amount) public view returns (uint256) {
        // VULNERABILITY 3: Integer division loses precision
        return amount / BASIS_POINTS * feePercentage;
        // Should be: (amount * feePercentage) / BASIS_POINTS
    }
    
    /**
     * @notice Transfer with fee
     * @dev VULNERABILITY 4: Rounding error accumulation
     */
    function transferWithFee(address to, uint256 amount) external returns (bool) {
        uint256 fee = calculateFee(amount);
        uint256 amountAfterFee = amount - fee;
        
        // VULNERABILITY 4: Fee might be 0 for small amounts
        balances[msg.sender] -= amount;
        balances[to] += amountAfterFee;
        balances[owner] += fee; // Fee goes to owner
        
        emit Transfer(msg.sender, to, amountAfterFee);
        emit Transfer(msg.sender, owner, fee);
        return true;
    }
    
    /**
     * @notice Approve spender
     * @dev VULNERABILITY 5: Front-running attack vector
     */
    function approve(address spender, uint256 amount) external returns (bool) {
        // VULNERABILITY 5: Direct overwrite enables front-running
        allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }
    
    // ============================================
    // Staking Functions
    // ============================================
    
    /**
     * @notice Stake tokens
     * @dev VULNERABILITY 6: No update of rewards before staking
     */
    function stake(uint256 amount) external {
        require(amount > 0, "Cannot stake 0");
        require(balances[msg.sender] >= amount, "Insufficient balance");
        
        // VULNERABILITY 6: Should update rewards first
        balances[msg.sender] -= amount;
        stakedAmount[msg.sender] += amount;
        
        emit Staked(msg.sender, amount);
    }
    
    /**
     * @notice Calculate pending rewards
     * @dev VULNERABILITY 7: Division before multiplication
     */
    function calculateRewards(address user) public view returns (uint256) {
        if (stakedAmount[user] == 0) return 0;
        
        uint256 blocks = block.number - lastRewardBlock;
        // VULNERABILITY 7: Division before multiplication loses precision
        uint256 reward = stakedAmount[user] / totalSupply * blocks * REWARD_RATE;
        return reward;
    }
    
    // ============================================
    // Price Oracle Functions
    // ============================================
    
    /**
     * @notice Convert token amount to USD value
     * @dev VULNERABILITY 8: Overflow in multiplication
     */
    function getValueInUSD(uint256 tokenAmount) external view returns (uint256) {
        // VULNERABILITY 8: Can overflow for large amounts
        unchecked {
            return tokenAmount * tokenPrice; // Missing division by 10**18
        }
    }
    
    /**
     * @notice Update token price
     * @dev VULNERABILITY 9: No validation of price input
     */
    function updatePrice(uint256 newPrice) external {
        // VULNERABILITY 9: Anyone can update, no validation
        uint256 oldPrice = tokenPrice;
        tokenPrice = newPrice;
        emit PriceUpdated(oldPrice, newPrice);
    }
    
    // ============================================
    // Division Functions
    // ============================================
    
    /**
     * @notice Divide balance equally among recipients
     * @dev VULNERABILITY 10: Dust amount due to rounding
     */
    function divideBalance(address[] memory recipients) external {
        require(recipients.length > 0, "No recipients");
        uint256 amount = balances[msg.sender];
        uint256 amountPerRecipient = amount / recipients.length;
        
        // VULNERABILITY 10: Dust remains due to integer division
        for (uint256 i = 0; i < recipients.length; i++) {
            balances[msg.sender] -= amountPerRecipient;
            balances[recipients[i]] += amountPerRecipient;
        }
        // Dust remains in sender's balance
    }
    
    /**
     * @notice Calculate percentage
     * @dev VULNERABILITY 11: Zero division check missing
     */
    function calculatePercentage(uint256 value, uint256 total) external pure returns (uint256) {
        // VULNERABILITY 11: No check for total == 0
        return (value * 100) / total;
    }
}

/**
 * @title NumbersAndMathSecure
 * @author Solidity Cookbook
 * @notice Secure version with all arithmetic vulnerabilities fixed
 * @dev Implements best practices for mathematical operations
 */
contract NumbersAndMathSecure {
    // ============================================
    // State Variables
    // ============================================
    
    // Token functionality
    mapping(address => uint256) public balances;
    mapping(address => mapping(address => uint256)) public allowances;
    uint256 public totalSupply;
    
    // Staking rewards system with accumulator pattern
    mapping(address => uint256) public stakedAmount;
    mapping(address => uint256) public rewardDebt;
    uint256 public accRewardPerShare; // Accumulated rewards per share
    uint256 public totalStaked;
    uint256 public lastRewardBlock;
    
    // Price oracle with bounds
    uint256 public tokenPrice = 1000000; // $1 with 6 decimals
    uint256 public constant PRICE_DECIMALS = 6;
    uint256 public constant MIN_PRICE = 1000; // $0.001
    uint256 public constant MAX_PRICE = 1000000000; // $1000
    
    // Fee system with precision
    uint256 public feePercentage = 300; // 3% = 300 basis points
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MAX_FEE = 1000; // 10% max
    
    // Fixed-point arithmetic constants
    uint256 public constant PRECISION = 1e18;
    uint256 public constant REWARD_RATE = 100 * PRECISION; // tokens per block
    
    // Access control
    address public owner;
    address public priceOracle;
    
    // ============================================
    // Events
    // ============================================
    
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 amount);
    event PriceUpdated(uint256 oldPrice, uint256 newPrice);
    event FeeUpdated(uint256 oldFee, uint256 newFee);
    
    // ============================================
    // Errors
    // ============================================
    
    error InsufficientBalance(uint256 requested, uint256 available);
    error InvalidAmount();
    error InvalidAddress();
    error InvalidPrice(uint256 price);
    error DivisionByZero();
    error Unauthorized();
    error FeeExceedsMaximum(uint256 fee);
    error NoRecipients();
    error ArrayTooLarge();
    
    // ============================================
    // Modifiers
    // ============================================
    
    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }
    
    modifier onlyPriceOracle() {
        if (msg.sender != priceOracle) revert Unauthorized();
        _;
    }
    
    modifier validAddress(address addr) {
        if (addr == address(0)) revert InvalidAddress();
        _;
    }
    
    modifier updateReward(address user) {
        // FIX 6: Always update rewards before state changes
        _updateRewards();
        if (user != address(0)) {
            uint256 pending = _pendingReward(user);
            if (pending > 0) {
                balances[user] += pending;
                emit RewardsClaimed(user, pending);
            }
            rewardDebt[user] = (stakedAmount[user] * accRewardPerShare) / PRECISION;
        }
        _;
    }
    
    // ============================================
    // Constructor
    // ============================================
    
    constructor() {
        owner = msg.sender;
        priceOracle = msg.sender; // Initially owner is oracle
        totalSupply = 1000000 * 10**18; // 1 million tokens
        balances[msg.sender] = totalSupply;
        lastRewardBlock = block.number;
    }
    
    // ============================================
    // Token Functions
    // ============================================
    
    /**
     * @notice Transfer tokens safely
     * @dev FIX 1 & 2: Solidity 0.8+ automatic overflow/underflow protection
     */
    function transfer(address to, uint256 amount) 
        external 
        validAddress(to) 
        returns (bool) 
    {
        if (amount == 0) revert InvalidAmount();
        
        uint256 senderBalance = balances[msg.sender];
        if (senderBalance < amount) {
            revert InsufficientBalance(amount, senderBalance);
        }
        
        // FIX 1 & 2: Safe arithmetic with Solidity 0.8+
        balances[msg.sender] = senderBalance - amount;
        balances[to] += amount;
        
        emit Transfer(msg.sender, to, amount);
        return true;
    }
    
    /**
     * @notice Calculate fee correctly
     * @dev FIX 3: Multiplication before division
     */
    function calculateFee(uint256 amount) public view returns (uint256) {
        if (amount == 0) return 0;
        // FIX 3: Multiply first, then divide
        return (amount * feePercentage) / BASIS_POINTS;
    }
    
    /**
     * @notice Transfer with fee (no rounding issues)
     * @dev FIX 4: Proper fee calculation with minimum amount checks
     */
    function transferWithFee(address to, uint256 amount) 
        external 
        validAddress(to) 
        returns (bool) 
    {
        if (amount == 0) revert InvalidAmount();
        
        uint256 fee = calculateFee(amount);
        uint256 amountAfterFee = amount - fee;
        
        // FIX 4: Ensure fee is meaningful
        require(amountAfterFee > 0, "Amount too small after fee");
        
        uint256 senderBalance = balances[msg.sender];
        if (senderBalance < amount) {
            revert InsufficientBalance(amount, senderBalance);
        }
        
        balances[msg.sender] = senderBalance - amount;
        balances[to] += amountAfterFee;
        if (fee > 0) {
            balances[owner] += fee;
            emit Transfer(msg.sender, owner, fee);
        }
        
        emit Transfer(msg.sender, to, amountAfterFee);
        return true;
    }
    
    /**
     * @notice Safe approve with front-running protection
     * @dev FIX 5: Increase/decrease pattern or require zero
     */
    function approve(address spender, uint256 amount) 
        external 
        validAddress(spender) 
        returns (bool) 
    {
        // FIX 5: Require current allowance to be 0 or use increase/decrease
        uint256 currentAllowance = allowances[msg.sender][spender];
        require(
            currentAllowance == 0 || amount == 0,
            "Use increaseAllowance or decreaseAllowance"
        );
        
        allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }
    
    function increaseAllowance(address spender, uint256 addedValue) 
        external 
        validAddress(spender) 
        returns (bool) 
    {
        uint256 currentAllowance = allowances[msg.sender][spender];
        uint256 newAllowance = currentAllowance + addedValue;
        
        allowances[msg.sender][spender] = newAllowance;
        emit Approval(msg.sender, spender, newAllowance);
        return true;
    }
    
    function decreaseAllowance(address spender, uint256 subtractedValue) 
        external 
        validAddress(spender) 
        returns (bool) 
    {
        uint256 currentAllowance = allowances[msg.sender][spender];
        require(currentAllowance >= subtractedValue, "Decreased allowance below zero");
        
        uint256 newAllowance = currentAllowance - subtractedValue;
        allowances[msg.sender][spender] = newAllowance;
        emit Approval(msg.sender, spender, newAllowance);
        return true;
    }
    
    // ============================================
    // Staking Functions
    // ============================================
    
    /**
     * @notice Stake tokens with reward update
     * @dev FIX 6: Update rewards before state change
     */
    function stake(uint256 amount) external updateReward(msg.sender) {
        if (amount == 0) revert InvalidAmount();
        
        uint256 userBalance = balances[msg.sender];
        if (userBalance < amount) {
            revert InsufficientBalance(amount, userBalance);
        }
        
        balances[msg.sender] = userBalance - amount;
        stakedAmount[msg.sender] += amount;
        totalStaked += amount;
        
        emit Staked(msg.sender, amount);
    }
    
    /**
     * @notice Unstake tokens
     */
    function unstake(uint256 amount) external updateReward(msg.sender) {
        if (amount == 0) revert InvalidAmount();
        
        uint256 userStaked = stakedAmount[msg.sender];
        if (userStaked < amount) {
            revert InsufficientBalance(amount, userStaked);
        }
        
        stakedAmount[msg.sender] = userStaked - amount;
        totalStaked -= amount;
        balances[msg.sender] += amount;
        
        emit Unstaked(msg.sender, amount);
    }
    
    /**
     * @notice Calculate rewards with precision
     * @dev FIX 7: Use accumulator pattern with precision
     */
    function _updateRewards() private {
        if (block.number <= lastRewardBlock) return;
        if (totalStaked == 0) {
            lastRewardBlock = block.number;
            return;
        }
        
        uint256 blocks = block.number - lastRewardBlock;
        uint256 reward = blocks * REWARD_RATE;
        
        // FIX 7: Precision-aware calculation
        accRewardPerShare += (reward * PRECISION) / totalStaked;
        lastRewardBlock = block.number;
    }
    
    function _pendingReward(address user) private view returns (uint256) {
        uint256 userStaked = stakedAmount[user];
        if (userStaked == 0) return 0;
        
        uint256 tempAccRewardPerShare = accRewardPerShare;
        
        if (block.number > lastRewardBlock && totalStaked > 0) {
            uint256 blocks = block.number - lastRewardBlock;
            uint256 reward = blocks * REWARD_RATE;
            tempAccRewardPerShare += (reward * PRECISION) / totalStaked;
        }
        
        return ((userStaked * tempAccRewardPerShare) / PRECISION) - rewardDebt[user];
    }
    
    function pendingReward(address user) external view returns (uint256) {
        return _pendingReward(user);
    }
    
    function claimRewards() external updateReward(msg.sender) {
        // Rewards are automatically claimed in the modifier
    }
    
    // ============================================
    // Price Oracle Functions
    // ============================================
    
    /**
     * @notice Convert tokens to USD safely
     * @dev FIX 8: Proper decimal handling
     */
    function getValueInUSD(uint256 tokenAmount) external view returns (uint256) {
        if (tokenAmount == 0) return 0;
        
        // FIX 8: Account for token decimals (18) and price decimals (6)
        // Result in price decimals (6)
        return (tokenAmount * tokenPrice) / 10**18;
    }
    
    /**
     * @notice Update price with validation
     * @dev FIX 9: Access control and validation
     */
    function updatePrice(uint256 newPrice) external onlyPriceOracle {
        // FIX 9: Validate price bounds
        if (newPrice < MIN_PRICE || newPrice > MAX_PRICE) {
            revert InvalidPrice(newPrice);
        }
        
        uint256 oldPrice = tokenPrice;
        tokenPrice = newPrice;
        emit PriceUpdated(oldPrice, newPrice);
    }
    
    function setPriceOracle(address newOracle) external onlyOwner validAddress(newOracle) {
        priceOracle = newOracle;
    }
    
    // ============================================
    // Division Functions
    // ============================================
    
    /**
     * @notice Divide balance with dust handling
     * @dev FIX 10: Handle remainder properly
     */
    function divideBalance(address[] memory recipients) external {
        uint256 recipientCount = recipients.length;
        if (recipientCount == 0) revert NoRecipients();
        if (recipientCount > 100) revert ArrayTooLarge(); // Gas limit protection
        
        uint256 totalAmount = balances[msg.sender];
        if (totalAmount == 0) revert InvalidAmount();
        
        uint256 amountPerRecipient = totalAmount / recipientCount;
        uint256 distributed = amountPerRecipient * recipientCount;
        uint256 dust = totalAmount - distributed;
        
        // FIX 10: Clear sender balance first
        balances[msg.sender] = 0;
        
        // Distribute equal amounts
        for (uint256 i = 0; i < recipientCount; i++) {
            if (recipients[i] == address(0)) revert InvalidAddress();
            balances[recipients[i]] += amountPerRecipient;
            emit Transfer(msg.sender, recipients[i], amountPerRecipient);
        }
        
        // FIX 10: Give dust to last recipient
        if (dust > 0) {
            balances[recipients[recipientCount - 1]] += dust;
            emit Transfer(msg.sender, recipients[recipientCount - 1], dust);
        }
    }
    
    /**
     * @notice Safe percentage calculation
     * @dev FIX 11: Check for division by zero
     */
    function calculatePercentage(uint256 value, uint256 total) 
        external 
        pure 
        returns (uint256) 
    {
        // FIX 11: Explicit zero check
        if (total == 0) revert DivisionByZero();
        if (value > total) return 100;
        
        return (value * 100) / total;
    }
    
    /**
     * @notice Calculate percentage with precision
     */
    function calculatePercentagePrecise(uint256 value, uint256 total) 
        external 
        pure 
        returns (uint256) 
    {
        if (total == 0) revert DivisionByZero();
        if (value > total) return 100 * PRECISION;
        
        // Return percentage with 18 decimals precision
        return (value * 100 * PRECISION) / total;
    }
    
    // ============================================
    // Admin Functions
    // ============================================
    
    function setFeePercentage(uint256 newFee) external onlyOwner {
        if (newFee > MAX_FEE) revert FeeExceedsMaximum(newFee);
        
        uint256 oldFee = feePercentage;
        feePercentage = newFee;
        emit FeeUpdated(oldFee, newFee);
    }
    
    function transferOwnership(address newOwner) external onlyOwner validAddress(newOwner) {
        owner = newOwner;
    }
}