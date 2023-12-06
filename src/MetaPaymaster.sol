// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

/* solhint-disable reason-string */

import "@account-abstraction/interfaces/IEntryPoint.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@solady/utils/SafeTransferLib.sol";

contract MetaPaymaster is OwnableUpgradeable {
    IEntryPoint public entryPoint;
    mapping(address => uint256) public balanceOf;
    uint256 public total;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address owner, IEntryPoint _entryPoint) public initializer {
        __Ownable_init(owner);
        entryPoint = _entryPoint;
    }

    function willFund(uint256 actualGasCost) public view returns (bool) {
        return balanceOf[msg.sender] >= actualGasCost && address(this).balance >= actualGasCost;
    }

    function fund(address paymaster, uint256 actualGasCost) external {
        require(balanceOf[msg.sender] >= actualGasCost);
        total -= actualGasCost;
        balanceOf[msg.sender] -= actualGasCost;
        entryPoint.depositTo{value: actualGasCost}(paymaster);
    }

    function depositTo(address account) public payable {
        total += msg.value;
        balanceOf[account] += msg.value;
    }

    function setBalance(address account, uint256 amount) public onlyOwner {
        if (amount > balanceOf[account]) {
            total += amount - balanceOf[account];
        } else {
            total -= balanceOf[account] - amount;
        }
        balanceOf[account] = amount;
    }

    function withdrawTo(address payable withdrawAddress, uint256 withdrawAmount) public onlyOwner {
        SafeTransferLib.safeTransferETH(withdrawAddress, withdrawAmount);
    }

    receive() external payable {}
}
