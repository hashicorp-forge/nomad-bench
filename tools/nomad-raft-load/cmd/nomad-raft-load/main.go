// Copyright (c) HashiCorp, Inc.
// SPDX-License-Identifier: MPL-2.0

package main

import (
	"flag"
	"fmt"
	"math/rand/v2"
	"os"
	"runtime"
	"sync"
	"time"

	"github.com/hashicorp/go-hclog"
	"github.com/hashicorp/nomad/api"
	"golang.org/x/time/rate"

	"github.com/hashicorp/nomad-bench/tools/nomad-raft-load/internal"
	"github.com/hashicorp/nomad-bench/tools/nomad-raft-load/internal/http"
	"github.com/hashicorp/nomad-bench/tools/nomad-raft-load/internal/telemetry"
	"github.com/hashicorp/nomad-bench/tools/nomad-raft-load/version"
)

var (
	nomadAddr = flag.String("nomad-addr", "", "The address of the Nomad server")
	httpAddr  = flag.String("http-addr", "0.0.0.0", "The address to bind the HTTP server to")
	httpPort  = flag.String("http-port", "8080", "The port to bind the HTTP server to")

	operationType    = flag.String("type", string(internal.OperationTypeToken), "The type of operation to perform (token or policy)")
	operationPattern = flag.String("pattern", string(internal.PatternCreateDelete), "The operation pattern (create-only, create-delete, accumulate-purge)")
	count            = flag.Int("count", 0, "The number of operations to perform per worker. If 0, runs continuously")
	reqRate          = flag.Float64("rate", 10, "The rate of operations per second")
	burstRate        = flag.Int("burst", 1, "The burst rate of operations")
	randomize        = flag.Bool("random", false, "Should the rate at which operations are performed be randomized?")
	seed1            = flag.Uint64("seed1", rand.Uint64(), "First uint64 of the PCG seed used by the random number generator")
	seed2            = flag.Uint64("seed2", rand.Uint64(), "Second uint64 of the PCG seed used by the random number generator")
	workers          = flag.Int("workers", 10*runtime.NumCPU(), "The number of workers to use")
	duration         = flag.Duration("duration", 0, "How long to run the test (0 means until count is reached)")
	purgeInterval    = flag.Duration("purge-interval", 0, "For accumulate-purge pattern, how often to purge accumulated resources (0 means only at end)")

	logLevel = flag.String("log-level", "INFO", "The log level to use")
	ver      = flag.Bool("version", false, "Prints out the version")
)

func main() {
	flag.Parse()

	if *ver {
		fmt.Printf("Version: %s\nCommit: %s\n", version.VERSION, version.GITCOMMIT)
		os.Exit(0)
	}

	logger := hclog.NewInterceptLogger(&hclog.LoggerOptions{
		Name:            "nomad-raft-load",
		Level:           hclog.LevelFromString(*logLevel),
		IncludeLocation: true,
	})

	// Validate flags
	opType := internal.OperationType(*operationType)
	if opType != internal.OperationTypeToken && opType != internal.OperationTypePolicy {
		logger.Error("invalid operation type", "type", *operationType)
		os.Exit(1)
	}

	opPattern := internal.OperationPattern(*operationPattern)
	if opPattern != internal.PatternCreateOnly &&
		opPattern != internal.PatternCreateDelete &&
		opPattern != internal.PatternAccumulatePurge {
		logger.Error("invalid operation pattern", "pattern", *operationPattern)
		os.Exit(1)
	}

	inMemorySink, err := telemetry.Setup()
	if err != nil {
		logger.Error("failed to setup telemetry", "error", err)
		os.Exit(1)
	}

	httpServer, err := http.NewServer(logger, *httpAddr, *httpPort, inMemorySink)
	if err != nil {
		logger.Error("failed to setup HTTP server", "error", err)
		os.Exit(1)
	}

	go httpServer.Server().ListenAndServe()

	// Initialize Nomad client
	config := api.DefaultConfig()
	config.Address = *nomadAddr
	c, err := api.NewClient(config)
	if err != nil {
		logger.Error("failed to start Nomad client", "error", err)
		os.Exit(1)
	}

	// Verify ACL system is enabled
	_, _, err = c.ACLTokens().List(nil)
	if err != nil {
		logger.Error("failed to query ACL tokens - ensure ACL system is bootstrapped", "error", err)
		os.Exit(1)
	}

	ops := internal.NewOperations(c, logger, opType, opPattern)

	var rng *rand.Rand
	lim := rate.NewLimiter(rate.Limit(*reqRate), *burstRate)

	if *randomize {
		rng = rand.New(rand.NewPCG(*seed1, *seed2))
		logger.Info("randomized operation delay", "seed", []uint64{*seed1, *seed2})
	}

	logger.Info("starting Raft load test",
		"operation_type", opType,
		"pattern", opPattern,
		"rate", *reqRate,
		"burst", *burstRate,
		"workers", *workers,
		"count_per_worker", *count,
		"duration", *duration)

	// Start periodic purge goroutine if needed
	var purgeDone chan bool
	if opPattern == internal.PatternAccumulatePurge && *purgeInterval > 0 {
		purgeDone = make(chan bool)
		go func() {
			ticker := time.NewTicker(*purgeInterval)
			defer ticker.Stop()
			for {
				select {
				case <-ticker.C:
					tokens, policies := ops.GetAccumulatedCount()
					logger.Info("periodic purge triggered", "tokens", tokens, "policies", policies)
					if err := ops.Purge(); err != nil {
						logger.Error("periodic purge failed", "error", err)
					}
				case <-purgeDone:
					return
				}
			}
		}()
	}

	// Start goroutines to perform operations
	var wg sync.WaitGroup
	wg.Add(*workers)

	startTime := time.Now()

	for i := 0; i < *workers; i++ {
		go ops.Run(&wg, i, *count, lim, rng)
	}

	// Wait for completion or duration timeout
	done := make(chan bool)
	go func() {
		wg.Wait()
		done <- true
	}()

	if *duration > 0 {
		select {
		case <-done:
			logger.Info("all workers completed")
		case <-time.After(*duration):
			logger.Info("duration reached, stopping test")
		}
	} else {
		<-done
		logger.Info("all workers completed")
	}

	elapsed := time.Since(startTime)

	// Stop periodic purge if running
	if purgeDone != nil {
		close(purgeDone)
	}

	// Final purge for accumulate-purge pattern
	if opPattern == internal.PatternAccumulatePurge {
		tokens, policies := ops.GetAccumulatedCount()
		if tokens > 0 || policies > 0 {
			logger.Info("performing final purge", "tokens", tokens, "policies", policies)
			if err := ops.Purge(); err != nil {
				logger.Error("final purge failed", "error", err)
			}
		}
	}

	logger.Info("Raft load test completed",
		"elapsed_time", elapsed,
		"operation_type", opType,
		"pattern", opPattern)
}
