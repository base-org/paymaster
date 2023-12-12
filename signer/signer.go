package signer

import (
	"crypto/ecdsa"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
)

type Signer interface {
	SignHash(h common.Hash) ([]byte, error)
}

type PrivateKeySigner struct {
	*ecdsa.PrivateKey
}

func (s *PrivateKeySigner) SignHash(h common.Hash) ([]byte, error) {
	signature, err := crypto.Sign(h[:], s.PrivateKey)
	if err == nil {
		signature[64] += 27
	}
	return signature, err
}
