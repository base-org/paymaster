// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@account-abstraction/interfaces/IEntryPoint.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@solady/utils/SafeTransferLib.sol";

/**
 * A meta-paymaster that deposits funds to the 4337 entryPoint on behalf
 * of allowlisted paymasters, just-in-time per userOperation.
 */
contract MetaPaymaster is OwnableUpgradeable {
    IEntryPoint public entryPoint;

    // Funds available to each individual paymaster
    mapping(address => uint256) public balanceOf;

    // Total funds allocated to all paymasters (sum of all balanceOf).
    // Tracked separately from the contract's balance, since balances
    // can be undercollateralized.
    uint256 public total;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the contract.
     * @param _owner The owner of the contract.
     * @param _entryPoint The 4337 EntryPoint contract.
     */
    function initialize(address _owner, IEntryPoint _entryPoint) public initializer {
        __Ownable_init(_owner);
        entryPoint = _entryPoint;
    }

    /**
     * @notice Helper function to check if this contract will fund a userOperation.
     * @param account The address that will call `fund` (usually the paymaster).
     * @param actualGasCost The actual gas cost of the userOp, including postOp overhead.
     * @return True if this contract will fund the given gas cost.
     */
    function willFund(address account, uint256 actualGasCost) public view returns (bool) {
        return balanceOf[account] >= actualGasCost && address(this).balance >= actualGasCost;
    }

    /**
     * @notice Deposits funds to the 4337 entryPoint on behalf of a paymaster.
     * @dev `actualGasCost` can be calculated using the formula:
     * `postOp.actualGasCost + postOpOverhead * gasPrice`, where `postOpOverhead`
     * is a constant representing the gas usage of the postOp function.
     * @param paymaster The paymaster to fund (`address(this)` when called from the paymaster).
     * @param actualGasCost The actual gas cost of the userOp, including postOp overhead.
     */
    function fund(address paymaster, uint256 actualGasCost) external {
        require(balanceOf[msg.sender] >= actualGasCost);
        total -= actualGasCost;
        balanceOf[msg.sender] -= actualGasCost;
        entryPoint.depositTo{value: actualGasCost}(paymaster);
    }

    /**
     * @notice Helper to deposit + associate funds with a particular paymaster.
     * @param account The address to associate the funds with.
     */
    function depositTo(address account) public payable {
        total += msg.value;
        balanceOf[account] += msg.value;
    }

    /**
     * @notice Sets the balance of a particular account / paymaster.
     * @param account The account to set the balance of.
     * @param amount The amount to set the balance to.
     */
    function setBalance(address account, uint256 amount) public onlyOwner {
        if (amount > balanceOf[account]) {
            total += amount - balanceOf[account];
        } else {
            total -= balanceOf[account] - amount;
        }
        balanceOf[account] = amount;
    }

    /**
     * @notice Withdraws funds from the contract.
     * @param withdrawAddress The address to withdraw to.
     * @param withdrawAmount The amount to withdraw.
     */
    function withdrawTo(address payable withdrawAddress, uint256 withdrawAmount) public onlyOwner {
        SafeTransferLib.safeTransferETH(withdrawAddress, withdrawAmount);
    }

    receive() external payable {}
}
