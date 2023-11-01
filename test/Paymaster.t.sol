// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Paymaster} from "../src/Paymaster.sol";
import {IEntryPoint} from "@account-abstraction/interfaces/IEntryPoint.sol";
import {IStakeManager} from "@account-abstraction/interfaces/IStakeManager.sol";
import {EntryPoint} from "@account-abstraction/core/EntryPoint.sol";
import {UserOperation} from "@account-abstraction/interfaces/UserOperation.sol";
import {SimpleAccountFactory} from "@account-abstraction/samples/SimpleAccountFactory.sol";
import {SimpleAccount} from "@account-abstraction/samples/SimpleAccount.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract PaymasterTest is Test {
    EntryPoint public entrypoint;
    Paymaster public paymaster;
    SimpleAccount public account;

    uint48 constant MOCK_VALID_UNTIL = 0x00000000deadbeef;
    uint48 constant MOCK_VALID_AFTER = 0x0000000000001234;
    bytes constant MOCK_SIG = "0x1234";
    address constant PAYMASTER_SIGNER = 0xC3Bf2750F0d47098f487D45b2FB26b32eCbAf9a2;
    uint256 constant PAYMASTER_SIGNER_KEY = 0x6a6c11c6f4703865cc4a88c6ebf0a605fdeeccd8052d66101d1d02730740a3c0;
    address constant ACCOUNT_OWNER = 0x39c0Bb04Bf6B779ac994f6A5211204e3Dbe16741;
    uint256 constant ACCOUNT_OWNER_KEY = 0x4034df11fcc455209edcb8948449a4dff732376dab6d03dc2d099d0084b0f023;

    function setUp() public {
        entrypoint = new EntryPoint();
        paymaster = new Paymaster(entrypoint, PAYMASTER_SIGNER);
        SimpleAccountFactory factory = new SimpleAccountFactory(entrypoint);
        account = factory.createAccount(ACCOUNT_OWNER, 0);
    }

    function test_zeroAddressVerifyingSigner() public {
        vm.expectRevert("Paymaster: verifyingSigner cannot be address(0)");
        new Paymaster(entrypoint, address(0));
    }

    function test_ownerVerifyingSigner() public {
        vm.expectRevert("Paymaster: verifyingSigner cannot be the owner");
        new Paymaster(entrypoint, address(this));
    }

    function test_noRenounceOwnership() public {
        vm.expectRevert("Paymaster: renouncing ownership is not allowed");
        paymaster.renounceOwnership();
    }

    function test_getHash() public {
        UserOperation memory userOp = createUserOp();
        userOp.initCode = "initCode";
        userOp.callData = "callData";
        bytes32 hash = paymaster.getHash(userOp, MOCK_VALID_UNTIL, MOCK_VALID_AFTER);
        assertEq(hash, 0xd3a02a83ba925f913230b3c805cd623d66f85d0d2548a6bfb5dea3aec9757630);
    }

    function test_setVerifyingSignerOnlyOwner() public {
        vm.broadcast(ACCOUNT_OWNER);
        vm.expectRevert("Ownable: caller is not the owner");
        paymaster.setVerifyingSigner(ACCOUNT_OWNER);
    }

    function test_validatePaymasterUserOpValidSignature() public {
        UserOperation memory userOp = createUserOp();
        signUserOp(userOp);

        vm.expectRevert(createEncodedValidationResult(false, 57126));
        entrypoint.simulateValidation(userOp);
    }

    function test_validatePaymasterUserOpUpdatedSigner() public {
        paymaster.setVerifyingSigner(ACCOUNT_OWNER);

        UserOperation memory userOp = createUserOp();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ACCOUNT_OWNER_KEY, ECDSA.toEthSignedMessageHash(paymaster.getHash(userOp, MOCK_VALID_UNTIL, MOCK_VALID_AFTER)));
        userOp.paymasterAndData = abi.encodePacked(address(paymaster), abi.encode(MOCK_VALID_UNTIL, MOCK_VALID_AFTER), r, s, v);
        signUserOp(userOp);

        vm.expectRevert(createEncodedValidationResult(false, 55126));
        entrypoint.simulateValidation(userOp);
    }

    function test_validatePaymasterUserOpWrongSigner() public {
        UserOperation memory userOp = createUserOp();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ACCOUNT_OWNER_KEY, ECDSA.toEthSignedMessageHash(paymaster.getHash(userOp, MOCK_VALID_UNTIL, MOCK_VALID_AFTER)));
        userOp.paymasterAndData = abi.encodePacked(address(paymaster), abi.encode(MOCK_VALID_UNTIL, MOCK_VALID_AFTER), r, s, v);
        signUserOp(userOp);

        vm.expectRevert(createEncodedValidationResult(true, 57132));
        entrypoint.simulateValidation(userOp);
    }

    function test_validatePaymasterUserOpNoSignature() public {
        UserOperation memory userOp = createUserOp();
        userOp.paymasterAndData = abi.encodePacked(address(paymaster), abi.encode(MOCK_VALID_UNTIL, MOCK_VALID_AFTER));
        signUserOp(userOp);

        vm.expectRevert(
            abi.encodeWithSelector(
                IEntryPoint.FailedOp.selector,
                0, "AA33 reverted: Paymaster: invalid signature length in paymasterAndData"
            )
        );
        entrypoint.simulateValidation(userOp);
    }

    function test_validatePaymasterUserOpInvalidSignature() public {
        UserOperation memory userOp = createUserOp();
        userOp.paymasterAndData = abi.encodePacked(address(paymaster), abi.encode(MOCK_VALID_UNTIL, MOCK_VALID_AFTER), bytes32(0), bytes32(0), uint8(0));
        signUserOp(userOp);

        vm.expectRevert(
            abi.encodeWithSelector(
                IEntryPoint.FailedOp.selector,
                0, "AA33 reverted: ECDSA: invalid signature"
            )
        );
        entrypoint.simulateValidation(userOp);
    }

    function createUserOp() public view returns (UserOperation memory) {
        UserOperation memory userOp;
        userOp.sender = address(account);
        userOp.verificationGasLimit = 100000;
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PAYMASTER_SIGNER_KEY, ECDSA.toEthSignedMessageHash(paymaster.getHash(userOp, MOCK_VALID_UNTIL, MOCK_VALID_AFTER)));
        userOp.paymasterAndData = abi.encodePacked(address(paymaster), abi.encode(MOCK_VALID_UNTIL, MOCK_VALID_AFTER), r, s, v);
        return userOp;
    }

    function signUserOp(UserOperation memory userOp) public view {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ACCOUNT_OWNER_KEY, ECDSA.toEthSignedMessageHash(entrypoint.getUserOpHash(userOp)));
        userOp.signature = abi.encodePacked(r, s, v);
    }

    function createEncodedValidationResult(bool sigFailed, uint256 preOpGas) public pure returns (bytes memory) {
        uint256 prefund = 0;
        bytes memory paymasterContext = "";
        return abi.encodeWithSelector(
            IEntryPoint.ValidationResult.selector,
            IEntryPoint.ReturnInfo(preOpGas, prefund, sigFailed, MOCK_VALID_AFTER, MOCK_VALID_UNTIL, paymasterContext),
            IStakeManager.StakeInfo(0, 0),
            IStakeManager.StakeInfo(0, 0),
            IStakeManager.StakeInfo(0, 0)
        );
    }
}
