# Recipe 1: Hello World - State Management and Access Control

## 📋 What You'll Learn
- Basic contract structure and state variables
- Function types (view, pure, external, public)
- Events and their proper usage
- Common access control vulnerabilities
- Security patterns (CEI, two-step transfers, modifiers)
- Gas optimization through error handling

## 🧩 Understanding the Ingredients

**1. License and Pragma**
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
```
- **Definition**: License identifier and compiler version specification
- **Purpose**: Legal clarity and version compatibility
- **Gas Cost**: No runtime cost (compile-time only)
- **Common Mistakes**: Using outdated compiler versions, missing license
- **Best Practice**: Use latest stable version (0.8.19+) for built-in overflow protection

**2. State Variables**
```solidity
string public greeting;          // 32KB+ for long strings
address public owner;            // 20 bytes
uint256 public updateCount;      // 32 bytes
mapping(address => uint256) public userUpdateCount;
```
- **Definition**: Permanent blockchain storage
- **Purpose**: Store contract's persistent data
- **Gas Cost**: 20,000 gas to initialize, 5,000 to modify, 2,100 to read
- **Common Mistakes**: Unnecessary state variables, not packing structs
- **Best Practice**: Minimize storage use, use events for historical data

**3. Function Visibility**
```solidity
external - Only callable from outside
public - Callable from anywhere  
internal - Only this contract and children
private - Only this contract
```
- **Definition**: Controls where functions can be called from
- **Purpose**: Access control and gas optimization
- **Gas Cost**: external < public for external calls
- **Common Mistakes**: Using public when external would suffice
- **Best Practice**: Use most restrictive visibility possible

**4. Function State Mutability**
```solidity
view - Reads state, no modifications
pure - No state access at all
payable - Can receive ETH
(none) - Can modify state
```
- **Definition**: Declares how function interacts with state
- **Purpose**: Gas optimization and clarity
- **Gas Cost**: view/pure = free when called externally
- **Common Mistakes**: Not marking read-only functions as view
- **Best Practice**: Always specify mutability explicitly

**5. Data Locations**
```solidity
storage - Permanent blockchain storage
memory - Temporary, exists during function call
calldata - Read-only function parameters
```
- **Definition**: Where data is stored during execution
- **Purpose**: Gas optimization and mutability control
- **Gas Cost**: calldata < memory < storage
- **Common Mistakes**: Using memory for read-only parameters
- **Best Practice**: Use calldata for read-only arrays/strings in external functions

**6. Events**
```solidity
event GreetingChanged(string indexed oldGreeting, string indexed newGreeting, address indexed changer);
```
- **Definition**: Logged data not stored in contract state
- **Purpose**: Off-chain monitoring and cheaper data storage
- **Gas Cost**: ~1,000 gas vs 20,000 for storage
- **Common Mistakes**: Not emitting events for state changes
- **Best Practice**: Emit events for all significant state changes

**7. Modifiers**
```solidity
modifier onlyOwner() {
    require(msg.sender == owner);
    _;  // Function body goes here
}
```
- **Definition**: Reusable function conditions
- **Purpose**: DRY principle for access control
- **Gas Cost**: Slight overhead vs inline requires
- **Common Mistakes**: Complex logic in modifiers
- **Best Practice**: Keep modifiers simple and focused

**8. Custom Errors (v0.8.4+)**
```solidity
error NotOwner(address caller);
revert NotOwner(msg.sender);
```
- **Definition**: Gas-efficient error handling
- **Purpose**: Cheaper than string-based reverts
- **Gas Cost**: ~200 gas vs ~700 for require strings
- **Common Mistakes**: Still using require with strings
- **Best Practice**: Use custom errors for production contracts

**9. Global Variables**
```solidity
msg.sender - Direct caller address
tx.origin - Original transaction initiator  
block.number - Current block number
block.timestamp - Current timestamp
```
- **Definition**: Transaction and block context
- **Purpose**: Access transaction/block information
- **Gas Cost**: Minimal (3 gas for most)
- **Common Mistakes**: Using tx.origin for authentication
- **Best Practice**: Never use tx.origin, always msg.sender

**10. Address Types**
```solidity
address - Basic address type
address payable - Can receive ETH
address(0) - Zero address (0x0000...)
```
- **Definition**: Ethereum account identifiers
- **Purpose**: Identify accounts and contracts
- **Gas Cost**: 20 bytes storage
- **Common Mistakes**: Not checking for zero address
- **Best Practice**: Always validate addresses aren't zero

## 📝 The Main Contract

See artifact `solidity_recipe_1` above for both vulnerable and secure implementations.

## 🧪 The Test File

See artifact `solidity_recipe_1_tests` above for comprehensive test suite.

## 🔒 Vulnerabilities Demonstrated

**1. Empty String Acceptance**
- **How it works**: No validation on input length allows empty strings
- **Real-world impact**: Breaks UI, confuses users, wastes gas
- **The fix**: Require minimum length of 1 character
- **Gas impact**: +100 gas for validation check
- **Historical example**: Various NFT metadata issues

**2. Gas Griefing via Long Strings**
- **How it works**: Unbounded string length can consume excessive gas
- **Real-world impact**: DoS attacks, transaction failures
- **The fix**: Set maximum length limit (280 chars)
- **Gas impact**: +100 gas for validation
- **Historical example**: Various contract DoS attacks

**3. tx.origin Authentication**
- **How it works**: Phishing contract tricks user into calling it
- **Real-world impact**: Unauthorized access, stolen funds
- **The fix**: Always use msg.sender, never tx.origin
- **Gas impact**: No difference
- **Historical example**: Early wallet vulnerabilities

**4. Zero Address Transfer**
- **How it works**: Transfer ownership to address(0) locks contract
- **Real-world impact**: Permanent loss of contract control
- **The fix**: Require non-zero address validation
- **Gas impact**: +100 gas for check
- **Historical example**: Parity wallet freeze (similar concept)

**5. Single-Step Ownership Transfer**
- **How it works**: Immediate transfer without confirmation
- **Real-world impact**: Accidental transfer to wrong/incompatible address
- **The fix**: Two-step transfer with acceptance
- **Gas impact**: +5,000 gas for additional storage
- **Historical example**: Multiple DeFi protocol incidents

**6. Missing Event Emissions**
- **How it works**: State changes without events
- **Real-world impact**: Impossible to track off-chain, poor UX
- **The fix**: Emit events for all state changes
- **Gas impact**: +1,000 gas per event
- **Historical example**: Early DEX implementations

**7. Reentrancy Vulnerability**
- **How it works**: External call before state update
- **Real-world impact**: Drain funds, corrupt state
- **The fix**: Checks-Effects-Interactions pattern
- **Gas impact**: No difference, just ordering
- **Historical example**: The DAO hack (2016)

## ⚡ Gas Optimization Tips

1. **Use Custom Errors**: Save ~500 gas per revert vs require strings
2. **Pack Storage Variables**: Combine variables <32 bytes in single slot
3. **Use calldata for Read-only Params**: Save ~100 gas per parameter
4. **Cache Storage Reads**: Save 97 gas per duplicate read
5. **Short-circuit Conditions**: Order conditions by likelihood

## 🎯 Key Security Patterns

**Checks-Effects-Interactions (CEI)**
- **Implementation**: Validate inputs → Update state → External calls
- **When to use**: Always when making external calls

**Two-Step Ownership Transfer**
- **Implementation**: initiate() → accept() pattern
- **When to use**: Any critical permission transfer

**Access Control Modifiers**
- **Implementation**: onlyOwner, notBlacklisted patterns
- **When to use**: Restricting function access

**Input Validation**
- **Implementation**: Length checks, zero checks, range checks
- **When to use**: All user-provided input

## 🏃 Running the Recipe

```bash
# Installation (if first recipe)
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Setup
forge init Recipe1-HelloWorld
cd Recipe1-HelloWorld

# Add files
# Copy contract to src/HelloWorld.sol
# Copy tests to test/HelloWorld.t.sol

# Run tests
forge test                          # Run all tests
forge test -vvv                     # Verbose output
forge test --match-test Vulnerable  # Run vulnerability tests
forge test --gas-report            # Gas analysis
forge coverage                      # Coverage report
forge test --fuzz-runs 10000       # Extended fuzzing
```

## 📊 Expected Test Output

```
[PASS] test_InitialState() (gas: 24,521)
[PASS] test_Vulnerability_EmptyString() (gas: 87,234)
[PASS] test_Vulnerability_TxOrigin() (gas: 125,432)
[PASS] test_Vulnerability_Reentrancy() (gas: 95,123)
[PASS] testFuzz_SetGreeting(string) (runs: 256, μ: 45,382, ~: 45,417)

Test result: ok. 25 passed; 0 failed; 
```

## 🔍 Debugging Common Issues

**Issue**: "Stack too deep" error
**Solution**: Extract complex logic into internal functions
**Prevention**: Limit local variables to 16

**Issue**: Tests failing with "EvmError: Revert"
**Solution**: Check error messages match exactly
**Prevention**: Use custom errors instead of strings

**Issue**: Fuzz tests taking too long
**Solution**: Add more restrictive vm.assume conditions
**Prevention**: Set reasonable bounds on inputs

## 💡 Practice Exercises

1. **Add Pausable Pattern**: Implement emergency pause functionality
   - Hint: Add `paused` state variable and `whenNotPaused` modifier
   - Learning goal: Emergency response patterns

2. **Add Update History**: Track last 10 greeting changes
   - Hint: Use fixed-size array and circular buffer pattern
   - Learning goal: Efficient storage patterns

3. **Add Voting System**: Require multiple approvals for changes
   - Hint: Track approvals in mapping, require threshold
   - Learning goal: Multi-sig patterns

4. **Add Fee Mechanism**: Charge ETH for updates
   - Hint: Make setGreeting payable, track balances
   - Learning goal: Payment handling

5. **Add Role-Based Access**: Multiple roles beyond owner
   - Hint: Use role mapping and role-specific modifiers
   - Learning goal: Advanced access control

6. **Add Time Locks**: Delay critical operations
   - Hint: Store operation timestamp, check elapsed time
   - Learning goal: Time-based security

## 🔗 Real-World Applications

**OpenZeppelin Ownable**: Industry standard ownership pattern
- Uses similar two-step transfer in latest versions
- Adds renounceOwnership for true decentralization

**ENS Registrar**: Uses similar patterns for domain management
- Events for all state changes
- Two-step transfers for domains

**Compound Governance**: Advanced access control
- Time locks on critical changes
- Multi-step proposal system

## 📚 Additional Resources

- [OpenZeppelin Ownable](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol)
- [SWC Registry - tx.origin](https://swcregistry.io/docs/SWC-115)
- [Consensys Best Practices](https://consensys.github.io/smart-contract-best-practices/)
- [Solidity Patterns](https://fravoll.github.io/solidity-patterns/)

## ✅ Checklist Before Moving On

Student should be able to:
- [ ] Explain difference between storage, memory, and calldata
- [ ] Identify tx.origin vulnerability
- [ ] Implement two-step ownership transfer
- [ ] Write tests with Foundry's vm cheatcodes
- [ ] Calculate gas costs for storage operations
- [ ] Apply Checks-Effects-Interactions pattern
- [ ] Use custom errors for gas efficiency
- [ ] Implement proper event emissions

## 🎪 Next Recipe Preview

In Recipe 2, we'll explore Numbers and Math operations, building on state management to learn about integer types, overflow protection, fixed-point arithmetic, and common mathematical vulnerabilities in DeFi protocols...