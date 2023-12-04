// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/MetaPaymaster.sol";
import "@account-abstraction/interfaces/IEntryPoint.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

// This script deploys a Paymaster
contract DeployPaymaster is Script {
    address entryPoint = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;

    function run() public {
        vm.broadcast();
        MetaPaymaster paymaster = new MetaPaymaster();
        vm.broadcast();
        ProxyAdmin admin = new ProxyAdmin();
        bytes memory data = abi.encodeWithSignature("initialize(address,address)", tx.origin, IEntryPoint(entryPoint));
        vm.broadcast();
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(paymaster), address(admin), data);
        require(address(MetaPaymaster(payable(proxy)).entryPoint()) == entryPoint);
        require(MetaPaymaster(payable(proxy)).owner() == tx.origin);
        require(admin.owner() == tx.origin);
    }
}
