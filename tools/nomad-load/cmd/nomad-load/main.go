package main

import (
	"context"
	"flag"
	"fmt"
	"math/rand/v2"
	"os"
	"runtime"
	"time"

	"github.com/hashicorp/go-hclog"
	"github.com/hashicorp/nomad/api"
	"golang.org/x/sync/errgroup"
	"golang.org/x/time/rate"

	"github.com/hashicorp/nomad-bench/tools/nomad-load/internal"
	"github.com/hashicorp/nomad-bench/tools/nomad-load/internal/http"
	"github.com/hashicorp/nomad-bench/tools/nomad-load/internal/telemetry"
	"github.com/hashicorp/nomad-bench/tools/nomad-load/version"
)

var (
	nomadAddr = flag.String("nomad-addr", "", "The address of the Nomad server")
	httpAddr  = flag.String("http-addr", "0.0.0.0", "The address to bind the HTTP server to")
	httpPort  = flag.String("http-port", "8080", "The port to bind the HTTP server to")

	jobType     = flag.String("type", internal.JobTypeBatch, "The type of job to create (batch or service)")
	jobDriver   = flag.String("driver", internal.JobDriverDocker, "The driver to use for the job (mock or docker)")
	updates     = flag.Bool("updates", false, "Should the service jobs be continuously updated?")
	updatesFreq = flag.Duration("updates-freq", time.Second, "The frequency at which to update the service jobs")
	count       = flag.Int("count", 1, "The count number per job (number of allocations is count * groups)")
	groups      = flag.Int("groups", 1, "The number of groups to create per job")
	spread      = flag.Bool("spread", false, "Should the jobs be spread across the datacenters?")
	reqRate     = flag.Float64("rate", 10, "The rate of constant job dispatches per second")
	burstRate   = flag.Int("burst", 1, "The burst rate of constant job dispatches")
	randomize   = flag.Bool("random", false, "Should the rate at which the jobs are dispatched be randomized?")
	seed1       = flag.Uint64("seed1", rand.Uint64(), "First uint64 of the PCG seed used by the random number generator")
	seed2       = flag.Uint64("seed2", rand.Uint64(), "Second uint64 of the PCG seed used by the random number generator")
	workers     = flag.Int("workers", 10*runtime.NumCPU(), "The number of workers to use")

	logLevel = flag.String("log-level", "DEBUG", "The log level to use")
	ver      = flag.Bool("version", false, "Prints out the version")
)

func main() {
	flag.Parse()

	if *ver {
		fmt.Printf("Version: %s\nCommit: %s\n", version.VERSION, version.GITCOMMIT)
		os.Exit(0)
	}

	logger := hclog.NewInterceptLogger(&hclog.LoggerOptions{
		Name:            "nomad-load",
		Level:           hclog.LevelFromString(*logLevel),
		IncludeLocation: true,
	})

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

	// Create errgroup to watch goroutines and start the HTTP server.
	g, ctx := errgroup.WithContext(context.Background())

	g.Go(httpServer.Server().ListenAndServe)

	// Initialize Nomad client and register test job.
	config := api.DefaultConfig()
	config.Address = *nomadAddr
	c, err := api.NewClient(config)
	if err != nil {
		logger.Error("failed to start Nomad client", "error", err)
		os.Exit(1)
	}

	jobConf := &internal.JobConf{
		JobType:    *jobType,
		Driver:     *jobDriver,
		Spread:     *spread,
		Count:      *count,
		GroupCount: *groups,
	}
	job := internal.NewJob(jobConf, c, logger)

	var rng *rand.Rand
	lim := rate.NewLimiter(rate.Limit(*reqRate), *burstRate)

	if *randomize {
		rng = rand.New(rand.NewPCG(*seed1, *seed2))
		logger.Info("randomized dispatch delay", "seed", []uint64{*seed1, *seed2})
	}

	if *jobType == internal.JobTypeBatch {
		if err := job.RegisterBatch(); err != nil {
			logger.Error("failed to register batch job", "error", err)
			os.Exit(1)
		}
	}

	// Start goroutines to register jobs.
	logger.Info("creating jobs", "rate", *reqRate, "burst", *burstRate)
	for i := 0; i < *workers; i++ {
		g.Go(func() error {
			return job.Run(ctx, lim, rng, i, false, *jobType)
		})
		if *updates && *jobType == internal.JobTypeService {
			ticker := time.NewTicker(*updatesFreq)
			done := make(chan bool)

			g.Go(func() error {
				for {
					select {
					case <-done:
						return nil
					case <-ticker.C:
						return job.Run(ctx, lim, rng, i, true, *jobType)
					}
				}
			})

			ticker.Stop()
			done <- true
		}
	}

	// Wait for results.
	err = g.Wait()
	if err != nil {
		logger.Error(err.Error())
		os.Exit(1)
	}
}
