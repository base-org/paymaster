# Base paymaster

This repo contains a verifying paymaster contract that can be used for gas subsidies for [ERC-4337](https://eips.ethereum.org/EIPS/eip-4337) transactions.
It contains a clone of the [eth-infinitism VerifyingPaymaster](https://github.com/eth-infinitism/account-abstraction/blob/73a676999999843f5086ee546e192cbef25c0c4a/contracts/samples/VerifyingPaymaster.sol) with an additional `receive()` function for simple deposits, as well as some additional changes made in response to an audit.

### Deployments

_(More coming soon)_

| Network      | Address                                                                                                                            |
|--------------|------------------------------------------------------------------------------------------------------------------------------------|
| Base Goerli  | [0x88Ad254d5b1a95C9Bd2ae5F87E2BE27d95d86c2f](https://goerli-explorer.base.org/address/0x88Ad254d5b1a95C9Bd2ae5F87E2BE27d95d86c2f)  |
| Base Sepolia | [0xf5d253B62543C6Ef526309D497f619CeF95aD430](https://sepolia-explorer.base.org/address/0xf5d253B62543C6Ef526309D497f619CeF95aD430) |

### Obtaining a signature for use with the paymaster contract

If you'd like to use the paymaster to sponsor your 4337 user operations, follow these steps:

1. Construct your user operation, without a paymaster set, and left unsigned.
2. Call `eth_paymasterAndDataForEstimateGas` JSON-RPC method on https://paymaster.base.org. Parameters:
   1. `Object` - the unsigned user operation
   2. `string` - the address of the entrypoint contract
   3. `string` - the chain ID, in hexadecimal
```shell
curl "https://paymaster.base.org" \
     -H 'content-type: application/json' \
     -d '
{
  "id": 1,
  "jsonrpc": "2.0",
  "method": "eth_paymasterAndDataForEstimateGas",
  "params": [
    {
      "sender": "0x0000000000000000000000000000000000000000",
      "nonce": "0x2a",
      "initCode": "0x",
      "callData": "0x",
      "callGasLimit": "0x1",
      "verificationGasLimit": "0x1",
      "preVerificationGas": "0x1",
      "maxFeePerGas": "0x1",
      "maxPriorityFeePerGas": "0x1"
    },
    "0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789",
    "0x14A33"
  ]
}
'
```
3. If the request is successful and the response contains a hex-encoded byte array, use that as the `paymasterAndData` field in the userOp for gas estimation in step 4.
Note that this is a dummy signature that won't be accepted by the paymaster, except for gas estimation.
If an error is returned or the result is empty, the paymaster is not available for the given operation or chain. You can stop here and choose to proceed with another paymaster or self-funding the user operation.
4. Call estimate gas on your bundler of choice.
5. Add some headroom to make room for additional paymaster verification gas. In our testing we've found the following values work, but it would depend on your bundler:
   1. `op.PreVerificationGas = estimate.PreVerificationGas + 2000`
   2. `op.VerificationGasLimit = estimate.VerificationGasLimit + 4000`
6. Call `eth_paymasterAndDataForUserOperation` JSON-RPC method on https://paymaster.base.org. Parameters:
   1. `Object` - the unsigned user operation
   2. `string` - the address of the entrypoint contract
   3. `string` - the chain ID, in hexadecimal
```shell
curl "https://paymaster.base.org" \
     -H 'content-type: application/json' \
     -d '
{
  "id": 1,
  "jsonrpc": "2.0",
  "method": "eth_paymasterAndDataForUserOperation",
  "params": [
    {
      "sender": "0x0000000000000000000000000000000000000000",
      "nonce": "0x2a",
      "initCode": "0x",
      "callData": "0x",
      "callGasLimit": "0x1",
      "verificationGasLimit": "0x1",
      "preVerificationGas": "0x1",
      "maxFeePerGas": "0x1",
      "maxPriorityFeePerGas": "0x1"
    },
    "0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789",
    "0x14A33"
  ]
}
'
```
7. If the request is successful and the response contains a hex-encoded byte array, use that as the `paymasterAndData` field in the userOp.
If an error is returned or the result is empty, the paymaster is not available for the given operation or chain. You can choose to proceed with another paymaster or self-funding the user operation.
8. Sign the user operation, and submit to your bundler of choice.

Note that the `paymasterAndData` returned in step 6 contains a signature of the provided userOp, so any modification of the userOp post step 6 (except for the `sig` field) will result in the paymaster rejecting the operation.

## Deploying and using your own paymaster

If you want to deploy your own paymaster, you can deploy [Paymaster.sol](./src/Paymaster.sol) to your chain of choice.
In order to generate signatures for your paymaster, there's a Golang package in the [signer](./signer) directory that allows you to sign userOperations that will be accepted by the paymaster (call `UserOperation.PaymasterSign`).
Of course you can also rewrite this in your language of choice; the Golang package will provide a good example.
