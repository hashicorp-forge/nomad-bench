// Copyright (c) HashiCorp, Inc.
// SPDX-License-Identifier: MPL-2.0

package internal

type OperationType string
type OperationPattern string

const (
	// Operation types - what Raft operations to perform
	OperationTypeToken     OperationType = "token"
	OperationTypePolicy    OperationType = "policy"
	OperationTypeVariable  OperationType = "variable"
	OperationTypeNamespace OperationType = "namespace"

	// Operation patterns - how to perform the operations
	PatternCreateOnly      OperationPattern = "create-only"
	PatternCreateDelete    OperationPattern = "create-delete"
	PatternAccumulatePurge OperationPattern = "accumulate-purge"
)
