# Recipe 2: Numbers and Math - Arithmetic Operations and Precision

## 📋 What You'll Learn
- Integer types and their limits (uint8 to uint256, int256)
- Arithmetic overflow/underflow protection in Solidity 0.8+
- Fixed-point arithmetic and precision handling
- Common DeFi mathematical vulnerabilities
- Safe patterns for fees, rewards, and token economics
- Division ordering and rounding error mitigation

## 🧩 Understanding the Ingredients

**1. Integer Types**
```solidity
uint8    // 0 to 255
uint256  // 0 to 2^256 - 1 (≈ 10^77)
int256   // -2^255 to 2^255 - 1
```
- **Definition**: Unsigned and signed integers of various sizes
- **Purpose**: Store whole numbers with different ranges
- **Gas Cost**: All types use 32-byte slots (except when packed)
- **Common Mistakes**: Using uint8 for counters (no gas savings)
- **Best Practice**: Use uint256 by default, smaller only for packing

**2. Arithmetic Operators**
```solidity
+ - * / % ** // Addition, subtraction, multiplication, division, modulo, exponentiation
```
- **Definition**: Basic mathematical operations
- **Purpose**: Perform calculations on-chain
- **Gas Cost**: 3-5 gas for basic ops, 10+ for division, 10-1000+ for exponentiation
- **Common Mistakes**: Division before multiplication (precision loss)
- **Best Practice**: Multiply first, divide last

**3. Overflow/Underflow Protection**
```solidity
// Solidity 0.8+: automatic protection
uint8 x = 255;
x + 1; // Reverts!

// Bypass with unchecked
unchecked { x + 1; } // Wraps to 0
```
- **Definition**: Automatic bounds checking since Solidity 0.8
- **Purpose**: Prevent silent wraparound errors
- **Gas Cost**: ~30 gas per operation for checks
- **Common Mistakes**: Using unchecked unnecessarily
- **Best Practice**: Only use unchecked when mathematically safe

**4. Fixed-Point Arithmetic**
```solidity
uint256 constant DECIMALS = 18;
uint256 constant ONE = 10**18; // 1.0
uint256 value = 1.5e18; // 1.5
```
- **Definition**: Representing decimals using integers
- **Purpose**: Solidity has no native decimal type
- **Gas Cost**: Same as integer operations
- **Common Mistakes**: Inconsistent decimal places
- **Best Practice**: Use 18 decimals (matches ETH)

**5. Basis Points**
```solidity
uint256 fee = 300; // 3% = 300 basis points
uint256 constant BASIS_POINTS = 10000;
```
- **Definition**: 1/100th of a percent (0.01%)
- **Purpose**: Precise percentage calculations
- **Gas Cost**: Regular integer math
- **Common Mistakes**: Confusing with percentages
- **Best Practice**: Always use BASIS_POINTS constant

**6. Order of Operations**
```solidity
// WRONG: Division first loses precision
fee = amount / BASIS_POINTS * feeRate;

// RIGHT: Multiplication first preserves precision  
fee = amount * feeRate / BASIS_POINTS;
```
- **Definition**: Sequence of mathematical operations
- **Purpose**: Preserve precision in calculations
- **Gas Cost**: Same total gas, different results
- **Common Mistakes**: Division before multiplication
- **Best Practice**: Multiply first, divide last

**7. Rounding Direction**
```solidity
// Round down (default)
result = a / b;

// Round up
result = (a + b - 1) / b;
```
- **Definition**: How to handle remainder in division
- **Purpose**: Control precision loss direction
- **Gas Cost**: +3 gas for round up
- **Common Mistakes**: Not considering rounding impact
- **Best Practice**: Round in protocol's favor

**8. Accumulator Pattern**
```solidity
accRewardPerShare += (reward * PRECISION) / totalStaked;
userReward = (userStake * accRewardPerShare) / PRECISION;
```
- **Definition**: Accumulate rewards/fees with precision
- **Purpose**: Fair distribution without loops
- **Gas Cost**: O(1) instead of O(n)
- **Common Mistakes**: Recalculating for each user
- **Best Practice**: Use for any per-share calculations

**9. Safe Comparison**
```solidity
if (a > b) { /* a is greater */ }
if (a >= b) { /* a is greater or equal */ }
// For percentages/ratios
if (a * 100 >= b * threshold) { /* threshold% check */ }
```
- **Definition**: Comparing integers safely
- **Purpose**: Avoid precision issues in comparisons
- **Gas Cost**: 3 gas per comparison
- **Common Mistakes**: Comparing calculated values with ==
- **Best Practice**: Use >= or <= for thresholds

**10. Gas-Efficient Math**
```solidity
// Expensive: x**2
// Cheap: x * x

// Expensive: x * 10**18
// Cheap: x * 1e18 (compile-time constant)
```
- **Definition**: Optimized arithmetic operations
- **Purpose**: Reduce gas costs
- **Gas Cost**: Varies significantly
- **Common Mistakes**: Using ** for small powers
- **Best Practice**: Use multiplication for powers ≤ 3

## 📝 The Main Contract

See artifact `solidity_recipe_2` above for both vulnerable and secure implementations.

## 🧪 The Test File

See artifact `solidity_recipe_2_tests` above for comprehensive test suite.

## 🔒 Vulnerabilities Demonstrated

**1. Integer Overflow**
- **How it works**: Adding to maximum value wraps to zero (pre-0.8)
- **Real-world impact**: Infinite token minting, balance corruption
- **The fix**: Solidity 0.8+ automatic checks or SafeMath library
- **Gas impact**: +30 gas per operation for checks
- **Historical example**: BeautyChain (BEC) overflow bug - $900M market cap to $0

**2. Integer Underflow**
- **How it works**: Subtracting below zero wraps to maximum (pre-0.8)
- **Real-world impact**: Spending more than balance, negative becomes huge positive
- **The fix**: Explicit balance checks before subtraction
- **Gas impact**: +30 gas for automatic checks
- **Historical example**: Various ERC20 tokens pre-2018

**3. Precision Loss in Fee Calculation**
- **How it works**: Integer division truncates remainder
- **Real-world impact**: Fees round to zero, protocol loses revenue
- **The fix**: Multiply before divide, use proper decimal handling
- **Gas impact**: No additional cost, just reordering
- **Historical example**: Multiple DEX fee calculation issues

**4. Rounding Error Accumulation**
- **How it works**: Small rounding errors compound over many operations
- **Real-world impact**: Dust accumulation, accounting mismatches
- **The fix**: Track remainders, use accumulator pattern
- **Gas impact**: +5,000 gas for additional storage
- **Historical example**: Compound Finance rounding issues

**5. Approval Front-Running**
- **How it works**: Attacker sees approval change in mempool, spends old allowance first
- **Real-world impact**: Double spending of allowances
- **The fix**: increaseAllowance/decreaseAllowance pattern
- **Gas impact**: Same gas, different functions
- **Historical example**: Various ERC20 implementations

**6. Reward Distribution Without Update**
- **How it works**: New staker dilutes rewards without distribution
- **Real-world impact**: Unfair reward distribution
- **The fix**: Update accumulator before any stake changes
- **Gas impact**: +200 gas for update check
- **Historical example**: Multiple yield farming exploits

**7. Division Before Multiplication**
- **How it works**: Early division loses precision
- **Real-world impact**: Incorrect calculations, lost value
- **The fix**: Always multiply first, divide last
- **Gas impact**: No difference
- **Historical example**: Various AMM pricing errors

**8. Value Calculation Overflow**
- **How it works**: Large number multiplication exceeds uint256
- **Real-world impact**: Incorrect valuations, arbitrage opportunities
- **The fix**: Check bounds, use proper decimal scaling
- **Gas impact**: +100 gas for validation
- **Historical example**: YAM Finance rebase bug

**9. Unvalidated Oracle Input**
- **How it works**: Accept any price without bounds checking
- **Real-world impact**: Price manipulation, liquidation attacks
- **The fix**: Min/max bounds, access control, multiple oracles
- **Gas impact**: +200 gas for validations
- **Historical example**: Multiple oracle manipulation attacks

**10. Division Remainder Loss**
- **How it works**: Integer division loses remainder
- **Real-world impact**: Dust accumulation, lost funds
- **The fix**: Track and distribute remainder
- **Gas impact**: +100 gas for remainder handling
- **Historical example**: Various token distribution contracts

**11. Division by Zero**
- **How it works**: Dividing by zero causes panic
- **Real-world impact**: DoS attacks, transaction failures
- **The fix**: Explicit zero checks before division
- **Gas impact**: +100 gas for check
- **Historical example**: Various DeFi protocol DoS vectors

## ⚡ Gas Optimization Tips

1. **Pack Variables**: Group uint128s, uint64s in single slot (save 20,000 gas)
2. **Use Constants**: `1e18` instead of `10**18` (compile-time evaluation)
3. **Avoid Exponentiation**: Use `x * x` instead of `x**2` (save 50+ gas)
4. **Cache Calculations**: Store repeated calculations (save 100+ gas)
5. **Batch Operations**: Update multiple values in one transaction

## 🎯 Key Security Patterns

**Checks-Effects-Interactions for Math**
- **Implementation**: Validate inputs → Calculate → Apply results
- **When to use**: Any calculation affecting state

**Accumulator Pattern**
- **Implementation**: Track accumulated value per share
- **When to use**: Distributing rewards/fees to many users

**Fixed-Point Arithmetic**
- **Implementation**: Use consistent decimal places (usually 18)
- **When to use**: Any fractional calculations

**Bounded Input Validation**
- **Implementation**: Min/max checks on all external inputs
- **When to use**: Oracle prices, user inputs, percentages

## 🏃 Running the Recipe

```bash
# Setup
forge init Recipe2-NumbersAndMath
cd Recipe2-NumbersAndMath

# Add files
# Copy contract to src/NumbersAndMath.sol
# Copy tests to test/NumbersAndMath.t.sol

# Run tests
forge test                          # Run all tests
forge test -vvv                     # Verbose output
forge test --match-test Vulnerability  # Vulnerability tests only
forge test --gas-report            # Gas usage analysis
forge coverage                      # Coverage report
forge test --fuzz-runs 10000       # Extended fuzzing
```

## 📊 Expected Test Output

```
[PASS] test_InitialState() (gas: 31,234)
[PASS] test_Vulnerability_PrecisionLoss() (gas: 45,123)
[PASS] test_Vulnerability_DivisionByZero() (gas: 8,234)
[PASS] test_Vulnerability_ApprovalFrontRunning() (gas: 67,890)
[PASS] testFuzz_FeeCalculation(uint256) (runs: 256, μ: 12,382, ~: 12,417)
[PASS] testFuzz_Percentage(uint256,uint256) (runs: 256, μ: 8,123, ~: 8,234)

Test result: ok. 32 passed; 0 failed;
```

## 🔍 Debugging Common Issues

**Issue**: "Arithmetic overflow" in tests
**Solution**: Check for multiplication of large numbers
**Prevention**: Add bounds checks or use unchecked carefully

**Issue**: Precision loss in calculations
**Solution**: Multiply before divide, use fixed-point math
**Prevention**: Always consider order of operations

**Issue**: Fuzz tests finding unexpected reverts
**Solution**: Add more vm.assume constraints
**Prevention**: Validate all input bounds

**Issue**: Gas costs too high for math operations
**Solution**: Cache repeated calculations, optimize operations
**Prevention**: Profile gas usage during development

## 💡 Practice Exercises

1. **Implement Compound Interest**: Calculate interest with daily compounding
   - Hint: Use exponential approximation for gas efficiency
   - Learning goal: Advanced fixed-point math

2. **Build a Bonding Curve**: Implement linear/exponential pricing
   - Hint: Price increases with supply
   - Learning goal: Complex mathematical relationships

3. **Create a Weighted Voting System**: Votes weighted by token balance and time
   - Hint: Use accumulator pattern for efficiency
   - Learning goal: Multi-factor calculations

4. **Add Slippage Protection**: Implement min/max output amounts
   - Hint: Calculate acceptable range based on percentage
   - Learning goal: Percentage-based bounds

5. **Build a Fee Splitter**: Distribute fees to multiple recipients by percentage
   - Hint: Handle remainder appropriately
   - Learning goal: Precise distribution math

6. **Implement a Rebase Token**: Adjust supply to maintain price peg
   - Hint: Scale all balances proportionally
   - Learning goal: Global state scaling

## 🔗 Real-World Applications

**Uniswap V2**: Constant product formula with precision handling
- Uses Q112.112 fixed-point for price accumulator
- Handles rounding in liquidity provider's favor

**Compound Finance**: Interest rate calculations with per-block accrual
- Uses mantissa (1e18) for all calculations
- Accumulator pattern for interest distribution

**MakerDAO**: Stability fee calculations with precision
- Uses RAY (27 decimals) and WAD (18 decimals)
- Careful rounding to prevent dust accumulation

## 📚 Additional Resources

- [OpenZeppelin SafeMath (pre-0.8)](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.4/contracts/math/SafeMath.sol)
- [PRBMath - Advanced Math Library](https://github.com/paulrberg/prb-math)
- [Fixed Point Arithmetic Guide](https://ethereum.org/en/developers/docs/smart-contracts/languages/solidity/fixed-point/)
- [DS-Math by DappHub](https://github.com/dapphub/ds-math)

## ✅ Checklist Before Moving On

Student should be able to:
- [ ] Explain overflow/underflow and Solidity 0.8 protections
- [ ] Implement fixed-point arithmetic correctly
- [ ] Identify precision loss in calculations
- [ ] Apply multiply-before-divide pattern
- [ ] Use accumulator pattern for distributions
- [ ] Handle rounding errors appropriately
- [ ] Implement safe percentage calculations
- [ ] Validate numerical inputs with bounds

## 🎪 Next Recipe Preview

In Recipe 3, we'll explore Arrays and Mappings, building on arithmetic to learn about gas-efficient data structures, iteration patterns, enumerable mappings, and common storage vulnerabilities in DeFi protocols...