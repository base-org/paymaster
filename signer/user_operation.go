package signer

import (
	"math/big"

	"github.com/ethereum/go-ethereum/accounts"
	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/ethereum/go-ethereum/crypto"
)

type UserOperation struct {
	Sender               common.Address `json:"sender"               mapstructure:"sender"               validate:"required"`
	Nonce                *hexutil.Big   `json:"nonce"                mapstructure:"nonce"                validate:"required"`
	InitCode             hexutil.Bytes  `json:"initCode"             mapstructure:"initCode"             validate:"required"`
	CallData             hexutil.Bytes  `json:"callData"             mapstructure:"callData"             validate:"required"`
	CallGasLimit         *hexutil.Big   `json:"callGasLimit"         mapstructure:"callGasLimit"         validate:"required"`
	VerificationGasLimit *hexutil.Big   `json:"verificationGasLimit" mapstructure:"verificationGasLimit" validate:"required"`
	PreVerificationGas   *hexutil.Big   `json:"preVerificationGas"   mapstructure:"preVerificationGas"   validate:"required"`
	MaxFeePerGas         *hexutil.Big   `json:"maxFeePerGas"         mapstructure:"maxFeePerGas"         validate:"required"`
	MaxPriorityFeePerGas *hexutil.Big   `json:"maxPriorityFeePerGas" mapstructure:"maxPriorityFeePerGas" validate:"required"`
	PaymasterAndData     hexutil.Bytes  `json:"paymasterAndData"     mapstructure:"paymasterAndData"     validate:"required"`
	Signature            hexutil.Bytes  `json:"signature"            mapstructure:"signature"            validate:"required"`
}

func (op *UserOperation) PaymasterSign(paymaster common.Address, chainID, validUntil, validAfter *big.Int, signer Signer) ([]byte, error) {
	hash, err := op.PaymasterHash(paymaster, chainID, validUntil, validAfter)
	if err != nil {
		return nil, err
	}
	h := common.BytesToHash(accounts.TextHash(hash[:]))
	return signer.SignHash(h)
}

func (op *UserOperation) PaymasterHash(paymaster common.Address, chainID, validUntil, validAfter *big.Int) (common.Hash, error) {
	address, _ := abi.NewType("address", "", nil)
	uint256, _ := abi.NewType("uint256", "", nil)
	uint48, _ := abi.NewType("uint48", "", nil)
	bytes32, _ := abi.NewType("bytes32", "", nil)
	args := abi.Arguments{
		{Name: "sender", Type: address},
		{Name: "nonce", Type: uint256},
		{Name: "hashInitCode", Type: bytes32},
		{Name: "hashCallData", Type: bytes32},
		{Name: "callGasLimit", Type: uint256},
		{Name: "verificationGasLimit", Type: uint256},
		{Name: "preVerificationGas", Type: uint256},
		{Name: "maxFeePerGas", Type: uint256},
		{Name: "maxPriorityFeePerGas", Type: uint256},
		{Name: "chainId", Type: uint256},
		{Name: "paymaster", Type: address},
		{Name: "validUntil", Type: uint48},
		{Name: "validAfter", Type: uint48},
	}
	packed, err := args.Pack(
		op.Sender,
		op.Nonce.ToInt(),
		crypto.Keccak256Hash(op.InitCode),
		crypto.Keccak256Hash(op.CallData),
		op.CallGasLimit.ToInt(),
		op.VerificationGasLimit.ToInt(),
		op.PreVerificationGas.ToInt(),
		op.MaxFeePerGas.ToInt(),
		op.MaxPriorityFeePerGas.ToInt(),
		chainID,
		paymaster,
		validUntil,
		validAfter,
	)
	if err != nil {
		return common.Hash{}, err
	}
	return crypto.Keccak256Hash(packed), nil
}
