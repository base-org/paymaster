// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@account-abstraction/core/BasePaymaster.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./MetaPaymaster.sol";

/**
 * Abstract paymaster that uses the `MetaPaymaster` for funding the
 * gas costs of each userOp by calling the `fund` method in `postOp`.
 */
abstract contract BaseFundedPaymaster is BasePaymaster {
    MetaPaymaster public immutable metaPaymaster;

    uint256 private constant POST_OP_OVERHEAD = 34982;

    constructor(IEntryPoint _entryPoint, MetaPaymaster _metaPaymaster) BasePaymaster(_entryPoint) Ownable() {
        metaPaymaster = _metaPaymaster;
    }

    function _validatePaymasterUserOp(UserOperation calldata userOp, bytes32 userOpHash, uint256 requiredPreFund)
    internal override returns (bytes memory context, uint256 validationData) {
        validationData = __validatePaymasterUserOp(userOp, userOpHash, requiredPreFund);
        return (abi.encode(userOp.maxFeePerGas, userOp.maxPriorityFeePerGas), validationData);
    }

    function __validatePaymasterUserOp(UserOperation calldata userOp, bytes32 userOpHash, uint256 maxCost)
    internal virtual returns (uint256 validationData);

    function _postOp(PostOpMode mode, bytes calldata context, uint256 actualGasCost) internal override {
        if (mode != PostOpMode.postOpReverted) {
            (uint256 maxFeePerGas, uint256 maxPriorityFeePerGas) = abi.decode(context, (uint256, uint256));
            uint256 gasPrice = min(maxFeePerGas, maxPriorityFeePerGas + block.basefee);
            metaPaymaster.fund(address(this), actualGasCost + POST_OP_OVERHEAD*gasPrice);
        }
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}
