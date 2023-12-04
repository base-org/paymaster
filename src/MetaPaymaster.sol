// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

/* solhint-disable reason-string */

import "@account-abstraction/interfaces/IEntryPoint.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract MetaPaymaster is OwnableUpgradeable {
    IEntryPoint public entryPoint;
    mapping(address => uint256) public balances;
    uint256 public total;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address owner, IEntryPoint _entryPoint) public initializer {
        __Ownable_init(owner);
        entryPoint = _entryPoint;
    }

    function fund(uint256 actualGasCost) external returns (bool) {
        if (address(this).balance < actualGasCost) {
            return false;
        }
        if (balances[msg.sender] < actualGasCost) {
            return false;
        }
        total -= actualGasCost;
        balances[msg.sender] -= actualGasCost;
        entryPoint.depositTo{value: actualGasCost}(msg.sender);
        return true;
    }

    function balance() public view returns (uint256) {
        return balances[msg.sender];
    }

    function balanceOf(address account) public view returns (uint256) {
        return balances[account];
    }

    function depositTo(address account) public payable {
        total += msg.value;
        balances[account] += msg.value;
    }

    function setBalance(address account, uint256 amount) public onlyOwner {
        total += amount - balances[account];
        balances[account] = amount;
    }

    function withdrawTo(address payable withdrawAddress, uint256 withdrawAmount) public onlyOwner {
        (bool success,) = withdrawAddress.call{value : withdrawAmount}("");
        require(success, "failed to withdraw");
    }

    receive() external payable {}
}
