// Copyright (c) HashiCorp, Inc.
// SPDX-License-Identifier: MPL-2.0

package internal

import (
	"context"
	"fmt"
	"math/rand/v2"
	"sync"
	"time"

	"github.com/hashicorp/go-hclog"
	"github.com/hashicorp/go-metrics"
	"github.com/hashicorp/nomad/api"
	"golang.org/x/time/rate"
)

// Operations handles Raft load testing operations
type Operations struct {
	client  *api.Client
	logger  hclog.Logger
	opType  OperationType
	pattern OperationPattern

	// Base policy for tokens
	basePolicyName string

	// Storage for accumulated resources (for accumulate-purge pattern)
	tokens     []string
	policies   []string
	variables  []string
	namespaces []string
	mu         sync.Mutex
}

// NewOperations creates a new Operations handler
func NewOperations(client *api.Client, logger hclog.Logger, opType OperationType, pattern OperationPattern) *Operations {
	ops := &Operations{
		client:         client,
		logger:         logger.Named("operations"),
		opType:         opType,
		pattern:        pattern,
		basePolicyName: "raft-load-base-policy",
		tokens:         make([]string, 0),
		policies:       make([]string, 0),
		variables:      make([]string, 0),
		namespaces:     make([]string, 0),
	}

	// Create a base policy for tokens if we're doing token operations
	if opType == OperationTypeToken {
		if err := ops.ensureBasePolicy(); err != nil {
			logger.Error("failed to create base policy for tokens", "error", err)
		}
	}

	return ops
}

// ensureBasePolicy creates a base policy that can be attached to tokens
func (o *Operations) ensureBasePolicy() error {
	policy := &api.ACLPolicy{
		Name: o.basePolicyName,
		Rules: `
namespace "default" {
  policy = "read"
}
`,
	}

	_, err := o.client.ACLPolicies().Upsert(policy, nil)
	if err != nil {
		return fmt.Errorf("failed to create base policy: %w", err)
	}

	o.logger.Info("created base policy for tokens", "policy", o.basePolicyName)
	return nil
}

// Run executes the load testing operations
func (o *Operations) Run(wg *sync.WaitGroup, workerID int, count int, lim *rate.Limiter, rng *rand.Rand) {
	defer wg.Done()

	logger := o.logger.With("worker", workerID, "operation_type", o.opType, "pattern", o.pattern)
	logger.Info("worker started")

	iterations := 0
	for {
		// Check if we've reached the desired count (0 means unlimited)
		if count > 0 && iterations >= count {
			logger.Info("worker completed", "iterations", iterations)
			break
		}

		// Apply rate limiting
		if lim != nil {
			// Add randomness if RNG is provided
			if rng != nil {
				delay := time.Duration(rng.Float64() * float64(time.Second))
				time.Sleep(delay)
			}
			if err := lim.Wait(context.Background()); err != nil {
				logger.Error("rate limiter error", "error", err)
				continue
			}
		}

		// Perform the operation based on type and pattern
		var err error
		start := time.Now()

		switch o.opType {
		case OperationTypeToken:
			err = o.handleTokenOperation(workerID, iterations)
		case OperationTypePolicy:
			err = o.handlePolicyOperation(workerID, iterations)
		case OperationTypeVariable:
			err = o.handleVariableOperation(workerID, iterations)
		case OperationTypeNamespace:
			err = o.handleNamespaceOperation(workerID, iterations)
		default:
			logger.Error("unknown operation type", "type", o.opType)
			return
		}

		duration := time.Since(start)

		if err != nil {
			logger.Error("operation failed", "error", err, "duration", duration)
			metrics.IncrCounter([]string{"operation", "errors"}, 1)
		} else {
			logger.Debug("operation completed", "duration", duration)
			metrics.IncrCounter([]string{"operation", "success"}, 1)
			metrics.AddSample([]string{"operation", "duration_ms"}, float32(duration.Milliseconds()))
		}

		iterations++
	}
}

// handleTokenOperation performs ACL token operations
func (o *Operations) handleTokenOperation(workerID, iteration int) error {
	tokenName := fmt.Sprintf("raft-load-token-%d-%d-%d", workerID, iteration, time.Now().UnixNano())

	switch o.pattern {
	case PatternCreateOnly:
		_, err := o.createToken(tokenName)
		return err

	case PatternCreateDelete:
		accessor, err := o.createToken(tokenName)
		if err != nil {
			return err
		}
		return o.deleteToken(accessor)

	case PatternAccumulatePurge:
		accessor, err := o.createToken(tokenName)
		if err != nil {
			return err
		}
		o.mu.Lock()
		o.tokens = append(o.tokens, accessor)
		o.mu.Unlock()
		return nil

	default:
		return fmt.Errorf("unknown pattern: %s", o.pattern)
	}
}

// handlePolicyOperation performs ACL policy operations
func (o *Operations) handlePolicyOperation(workerID, iteration int) error {
	policyName := fmt.Sprintf("raft-load-policy-%d-%d-%d", workerID, iteration, time.Now().UnixNano())

	switch o.pattern {
	case PatternCreateOnly:
		return o.createPolicy(policyName)

	case PatternCreateDelete:
		err := o.createPolicy(policyName)
		if err != nil {
			return err
		}
		return o.deletePolicy(policyName)

	case PatternAccumulatePurge:
		err := o.createPolicy(policyName)
		if err != nil {
			return err
		}
		o.mu.Lock()
		o.policies = append(o.policies, policyName)
		o.mu.Unlock()
		return nil

	default:
		return fmt.Errorf("unknown pattern: %s", o.pattern)
	}
}

// handleVariableOperation performs Nomad Variable operations
func (o *Operations) handleVariableOperation(workerID, iteration int) error {
	variablePath := fmt.Sprintf("raft-load/test-%d-%d-%d", workerID, iteration, time.Now().UnixNano())

	switch o.pattern {
	case PatternCreateOnly:
		return o.createVariable(variablePath)

	case PatternCreateDelete:
		err := o.createVariable(variablePath)
		if err != nil {
			return err
		}
		return o.deleteVariable(variablePath)

	case PatternAccumulatePurge:
		err := o.createVariable(variablePath)
		if err != nil {
			return err
		}
		o.mu.Lock()
		o.variables = append(o.variables, variablePath)
		o.mu.Unlock()
		return nil

	default:
		return fmt.Errorf("unknown pattern: %s", o.pattern)
	}
}

// handleNamespaceOperation performs Namespace operations
func (o *Operations) handleNamespaceOperation(workerID, iteration int) error {
	namespaceName := fmt.Sprintf("raft-load-ns-%d-%d-%d", workerID, iteration, time.Now().UnixNano())

	switch o.pattern {
	case PatternCreateOnly:
		return o.createNamespace(namespaceName)

	case PatternCreateDelete:
		err := o.createNamespace(namespaceName)
		if err != nil {
			return err
		}
		return o.deleteNamespace(namespaceName)

	case PatternAccumulatePurge:
		err := o.createNamespace(namespaceName)
		if err != nil {
			return err
		}
		o.mu.Lock()
		o.namespaces = append(o.namespaces, namespaceName)
		o.mu.Unlock()
		return nil

	default:
		return fmt.Errorf("unknown pattern: %s", o.pattern)
	}
}

// createToken creates an ACL token and returns its accessor ID
func (o *Operations) createToken(name string) (string, error) {
	token := &api.ACLToken{
		Name:     name,
		Type:     "client",
		Policies: []string{o.basePolicyName},
	}

	created, _, err := o.client.ACLTokens().Create(token, nil)
	if err != nil {
		return "", fmt.Errorf("failed to create token: %w", err)
	}

	metrics.IncrCounter([]string{"token", "created"}, 1)
	return created.AccessorID, nil
}

// deleteToken deletes an ACL token by accessor ID
func (o *Operations) deleteToken(accessor string) error {
	_, err := o.client.ACLTokens().Delete(accessor, nil)
	if err != nil {
		return fmt.Errorf("failed to delete token: %w", err)
	}

	metrics.IncrCounter([]string{"token", "deleted"}, 1)
	return nil
}

// createPolicy creates an ACL policy
func (o *Operations) createPolicy(name string) error {
	policy := &api.ACLPolicy{
		Name: name,
		Rules: `
namespace "default" {
  policy = "read"
}
`,
	}

	_, err := o.client.ACLPolicies().Upsert(policy, nil)
	if err != nil {
		return fmt.Errorf("failed to create policy: %w", err)
	}

	metrics.IncrCounter([]string{"policy", "created"}, 1)
	return nil
}

// deletePolicy deletes an ACL policy by name
func (o *Operations) deletePolicy(name string) error {
	_, err := o.client.ACLPolicies().Delete(name, nil)
	if err != nil {
		return fmt.Errorf("failed to delete policy: %w", err)
	}

	metrics.IncrCounter([]string{"policy", "deleted"}, 1)
	return nil
}

// createVariable creates a Nomad Variable
func (o *Operations) createVariable(path string) error {
	variable := &api.Variable{
		Path: path,
		Items: map[string]string{
			"test-key-1": "test-value-1",
			"test-key-2": "test-value-2",
			"timestamp":  time.Now().Format(time.RFC3339),
		},
	}

	_, _, err := o.client.Variables().Create(variable, nil)
	if err != nil {
		return fmt.Errorf("failed to create variable: %w", err)
	}

	metrics.IncrCounter([]string{"variable", "created"}, 1)
	return nil
}

// deleteVariable deletes a Nomad Variable by path
func (o *Operations) deleteVariable(path string) error {
	_, err := o.client.Variables().Delete(path, nil)
	if err != nil {
		return fmt.Errorf("failed to delete variable: %w", err)
	}

	metrics.IncrCounter([]string{"variable", "deleted"}, 1)
	return nil
}

// createNamespace creates a Nomad Namespace
func (o *Operations) createNamespace(name string) error {
	namespace := &api.Namespace{
		Name:        name,
		Description: "raft-load test namespace",
	}

	_, err := o.client.Namespaces().Register(namespace, nil)
	if err != nil {
		return fmt.Errorf("failed to create namespace: %w", err)
	}

	metrics.IncrCounter([]string{"namespace", "created"}, 1)
	return nil
}

// deleteNamespace deletes a Nomad Namespace by name
func (o *Operations) deleteNamespace(name string) error {
	_, err := o.client.Namespaces().Delete(name, nil)
	if err != nil {
		return fmt.Errorf("failed to delete namespace: %w", err)
	}

	metrics.IncrCounter([]string{"namespace", "deleted"}, 1)
	return nil
}

// Purge removes all accumulated resources (for accumulate-purge pattern)
func (o *Operations) Purge() error {
	o.mu.Lock()
	tokens := make([]string, len(o.tokens))
	policies := make([]string, len(o.policies))
	variables := make([]string, len(o.variables))
	namespaces := make([]string, len(o.namespaces))
	copy(tokens, o.tokens)
	copy(policies, o.policies)
	copy(variables, o.variables)
	copy(namespaces, o.namespaces)
	o.mu.Unlock()

	o.logger.Info("starting purge", "tokens", len(tokens), "policies", len(policies), "variables", len(variables), "namespaces", len(namespaces))

	var errs []error

	// Delete all tokens
	for _, accessor := range tokens {
		if err := o.deleteToken(accessor); err != nil {
			errs = append(errs, err)
		}
	}

	// Delete all policies
	for _, name := range policies {
		if err := o.deletePolicy(name); err != nil {
			errs = append(errs, err)
		}
	}

	// Delete all variables
	for _, path := range variables {
		if err := o.deleteVariable(path); err != nil {
			errs = append(errs, err)
		}
	}

	// Delete all namespaces
	for _, name := range namespaces {
		if err := o.deleteNamespace(name); err != nil {
			errs = append(errs, err)
		}
	}

	o.mu.Lock()
	o.tokens = make([]string, 0)
	o.policies = make([]string, 0)
	o.variables = make([]string, 0)
	o.namespaces = make([]string, 0)
	o.mu.Unlock()

	if len(errs) > 0 {
		return fmt.Errorf("purge completed with %d errors", len(errs))
	}

	o.logger.Info("purge completed successfully")
	return nil
}

// GetAccumulatedCount returns the number of accumulated resources
func (o *Operations) GetAccumulatedCount() (tokens int, policies int, variables int, namespaces int) {
	o.mu.Lock()
	defer o.mu.Unlock()
	return len(o.tokens), len(o.policies), len(o.variables), len(o.namespaces)
}

// CleanupBasePolicy removes the base policy used for token creation
func (o *Operations) CleanupBasePolicy() error {
	if o.opType != OperationTypeToken {
		return nil
	}

	_, err := o.client.ACLPolicies().Delete(o.basePolicyName, nil)
	if err != nil {
		return fmt.Errorf("failed to delete base policy: %w", err)
	}

	o.logger.Info("deleted base policy", "policy", o.basePolicyName)
	return nil
}
