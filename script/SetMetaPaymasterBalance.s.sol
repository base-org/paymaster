// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/meta/MetaPaymaster.sol";

contract SetMetaPaymasterBalance is Script {
    MetaPaymaster metaPaymaster = MetaPaymaster(payable(0x75B9328BB753144705b77b215E304eC7ef45235C));

    function run(address account, uint256 amount) public {
        vm.broadcast();
        metaPaymaster.setBalance(account, amount);
        require(metaPaymaster.balanceOf(account) == amount);
    }
}
