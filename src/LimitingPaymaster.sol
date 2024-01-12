// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

/* solhint-disable reason-string */

import "@account-abstraction/core/BasePaymaster.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * A paymaster that uses external service to decide whether to pay for the UserOp.
 * Also limits spending to "spendMax" per "spentKey", passed in via paymaster data.
 * The paymaster trusts an external signer to sign the transaction.
 * The calling user must pass the UserOp to that external signer first, which performs
 * whatever off-chain verification before signing the UserOp.
 * Note that this signature is NOT a replacement for the account-specific signature:
 * - the paymaster checks a signature to agree to PAY for GAS.
 * - the account checks a signature to prove identity and account ownership.
 */
contract LimitingPaymaster is BasePaymaster {
    using UserOperationLib for UserOperation;

    address public immutable verifyingSigner;

    mapping (uint32 => uint96) public spent;
    mapping (address => bool) public bundlerAllowed;

    constructor(IEntryPoint _entryPoint, address _verifyingSigner) BasePaymaster(_entryPoint) Ownable() {
        require(address(_entryPoint).code.length > 0, "Paymaster: passed _entryPoint is not currently a contract");
        require(_verifyingSigner != address(0), "Paymaster: verifyingSigner cannot be address(0)");
        require(_verifyingSigner != msg.sender, "Paymaster: verifyingSigner cannot be the owner");
        verifyingSigner = _verifyingSigner;
    }

    /**
     * return the hash we're going to sign off-chain (and validate on-chain)
     * this method is called by the off-chain service, to sign the request.
     * it is called on-chain from the validatePaymasterUserOp, to validate the signature.
     * note that this signature covers all fields of the UserOperation, except the "paymasterAndData",
     * which will carry the signature itself.
     */
    function getHash(UserOperation calldata userOp, uint48 validUntil, uint48 validAfter, uint32 spentKey, uint96 spentMax, bool allowAnyBundler)
    public view returns (bytes32) {
        // can't use userOp.hash(), since it contains also the paymasterAndData itself.
        return keccak256(
            abi.encode(
                userOp.getSender(),
                userOp.nonce,
                calldataKeccak(userOp.initCode),
                calldataKeccak(userOp.callData),
                userOp.callGasLimit,
                userOp.verificationGasLimit,
                userOp.preVerificationGas,
                userOp.maxFeePerGas,
                userOp.maxPriorityFeePerGas,
                block.chainid,
                address(this),
                validUntil,
                validAfter,
                spentKey,
                spentMax,
                allowAnyBundler
            )
        );
    }

    /**
     * verify our external signer signed this request.
     * the "paymasterAndData" is expected to be the paymaster and a signature over the entire request params
     * paymasterAndData[:20] : address(this)
     * paymasterAndData[20:26] : validUntil
     * paymasterAndData[26:32] : validAfter
     * paymasterAndData[32:36] : spendKey
     * paymasterAndData[36:48] : spendMax
     * paymasterAndData[48] : allowAnyBundler
     * paymasterAndData[49:114] : signature
     */
    function _validatePaymasterUserOp(UserOperation calldata userOp, bytes32 /*userOpHash*/, uint256 requiredPreFund)
    internal view override returns (bytes memory context, uint256 validationData) {
        (uint48 validUntil, uint48 validAfter, uint32 spentKey, uint96 spentMax, bool allowAnyBundler, bytes calldata signature) = parsePaymasterAndData(userOp.paymasterAndData);
        require(spent[spentKey] + requiredPreFund <= spentMax, "Paymaster: spender funds are depleted");
        // Only support 65-byte signatures, to avoid potential replay attacks.
        require(signature.length == 65, "Paymaster: invalid signature length in paymasterAndData");
        bytes32 hash = ECDSA.toEthSignedMessageHash(getHash(userOp, validUntil, validAfter, spentKey, spentMax, allowAnyBundler));

        // don't revert on signature failure: return SIG_VALIDATION_FAILED
        if (verifyingSigner != ECDSA.recover(hash, signature)) {
            return ("", _packValidationData(true, validUntil, validAfter));
        }

        // no need for other on-chain validation: entire UserOp should have been checked
        // by the external service prior to signing it.
        return (abi.encode(spentKey, allowAnyBundler), _packValidationData(false, validUntil, validAfter));
    }

    function _postOp(PostOpMode mode, bytes calldata context, uint256 actualGasCost) internal override {
        (uint32 spentKey, bool allowAnyBundler) = abi.decode(context, (uint32, bool));
        // unfortunately tx.origin is not allowed in validation, so we check here
        require(allowAnyBundler || bundlerAllowed[tx.origin], "Paymaster: bundler not allowed");

        if (mode != PostOpMode.postOpReverted) {
            spent[spentKey] += uint96(actualGasCost);
        }
    }

    function parsePaymasterAndData(bytes calldata paymasterAndData)
    internal pure returns(uint48 validUntil, uint48 validAfter, uint32 spentKey, uint96 spentMax, bool allowAnyBundler, bytes calldata signature) {
        validUntil = uint48(bytes6(paymasterAndData[20:26]));
        validAfter = uint48(bytes6(paymasterAndData[26:32]));
        spentKey = uint32(bytes4(paymasterAndData[32:36]));
        spentMax = uint96(bytes12(paymasterAndData[36:48]));
        allowAnyBundler = paymasterAndData[48] > 0;
        signature = paymasterAndData[49:];
    }

    function renounceOwnership() public override view onlyOwner {
        revert("Paymaster: renouncing ownership is not allowed");
    }

    function transferOwnership(address newOwner) public override onlyOwner {
        require(newOwner != address(0), "Paymaster: owner cannot be address(0)");
        require(newOwner != verifyingSigner, "Paymaster: owner cannot be the verifyingSigner");
        _transferOwnership(newOwner);
    }

    function addBundler(address bundler) public onlyOwner {
        bundlerAllowed[bundler] = true;
    }

    function removeBundler(address bundler) public onlyOwner {
        bundlerAllowed[bundler] = false;
    }

    receive() external payable {
        // use address(this).balance rather than msg.value in case of force-send
        (bool callSuccess, ) = payable(address(entryPoint)).call{value: address(this).balance}("");
        require(callSuccess, "Deposit failed");
    }
}
