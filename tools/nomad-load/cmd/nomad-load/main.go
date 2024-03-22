package main

import (
	"context"
	"flag"
	"fmt"
	"math/rand/v2"
	"net/http"
	"os"
	"runtime"
	"strings"
	"time"

	"github.com/hashicorp/go-hclog"
	"github.com/hashicorp/go-metrics"
	metricsprom "github.com/hashicorp/go-metrics/prometheus"
	"github.com/hashicorp/nomad/api"
	"github.com/hashicorp/nomad/jobspec2"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"golang.org/x/sync/errgroup"
	"golang.org/x/time/rate"

	"github.com/hashicorp/nomad-bench/tools/nomad-load/job"
	"github.com/hashicorp/nomad-bench/tools/nomad-load/version"
)

var (
	nomadAddr = flag.String("nomad-addr", "", "The address of the Nomad server")
	httpAddr  = flag.String("http-addr", "0.0.0.0", "The address to bind the HTTP server to")
	httpPort  = flag.String("http-port", "8080", "The port to bind the HTTP server to")

	count     = flag.Int("count", 1, "The count number per job (number of allocations is count * groups)")
	groups    = flag.Int("groups", 1, "The number of groups to create per job")
	spread    = flag.Bool("spread", false, "Should the jobs be spread across the datacenters?")
	reqRate   = flag.Float64("rate", 10, "The rate of constant job dispatches per second")
	burstRate = flag.Int("burst", 1, "The burst rate of constant job dispatches")
	randomize = flag.Bool("random", false, "Should the rate at which the jobs are dispatched be randomized?")
	seed1     = flag.Uint64("seed1", rand.Uint64(), "First uint64 of the PCG seed used by the random number generator")
	seed2     = flag.Uint64("seed2", rand.Uint64(), "Second uint64 of the PCG seed used by the random number generator")
	workers   = flag.Int("workers", 10*runtime.NumCPU(), "The number of workers to use")

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

	// Start metrics collection.
	promHandler := promhttp.HandlerFor(prometheus.DefaultGatherer, promhttp.HandlerOpts{
		ErrorLog:           logger.Named("prometheus").StandardLogger(nil),
		ErrorHandling:      promhttp.ContinueOnError,
		DisableCompression: true,
	})
	promSink, err := metricsprom.NewPrometheusSink()
	if err != nil {
		logger.Error("failed to start Prometheus sink", "error", err)
		os.Exit(1)
	}
	_, err = metrics.NewGlobal(metrics.DefaultConfig("nomad-load"), promSink)
	if err != nil {
		logger.Error("failed to register Prometheus metrics", "error", err)
	}

	// Create errgroup to watch goroutines.
	g, ctx := errgroup.WithContext(context.Background())

	// Start HTTP server for metrics.
	mux := http.NewServeMux()
	mux.Handle("/v1/metrics", promHandler)

	httpServer := &http.Server{
		Addr:    fmt.Sprintf("%s:%s", *httpAddr, *httpPort),
		Handler: mux,
	}
	g.Go(httpServer.ListenAndServe)

	// Initialize Nomad client and register test job.
	config := api.DefaultConfig()
	config.Address = *nomadAddr
	c, err := api.NewClient(config)
	if err != nil {
		logger.Error("failed to start Nomad client", "error", err)
		os.Exit(1)
	}

	jobspecConf := job.Conf{
		Spread:     *spread,
		Count:      *count,
		GroupCount: *groups,
	}

	// read the jobspec template and render it
	jobspec, err := job.Render(jobspecConf)
	if err != nil {
		logger.Error("failed to render job", "error", err)
		os.Exit(1)
	}

	r := strings.NewReader(jobspec)
	j, err := jobspec2.Parse("job.nomad.hcl", r)
	if err != nil {
		logger.Error("failed to parse job", "error", err)
		os.Exit(1)
	}

	_, _, err = c.Jobs().Register(j, nil)
	if err != nil {
		logger.Error("failed to register test job", "error", err)
		os.Exit(1)
	}

	var rng *rand.Rand
	lim := rate.NewLimiter(rate.Limit(*reqRate), *burstRate)

	// Start goroutines to dispatch job.
	logger.Info("dispatching jobs", "rate", *reqRate, "burst", *burstRate)
	if *randomize {
		rng = rand.New(rand.NewPCG(*seed1, *seed2))
		logger.Info("randomized dispatch delay", "seed", []uint64{*seed1, *seed2})
	}
	for i := 0; i < *workers; i++ {
		g.Go(func() error {
			return dispatch(ctx, logger, lim, rng, c, *j.ID)
		})
	}

	// Wait for results.
	err = g.Wait()
	if err != nil {
		logger.Error(err.Error())
		os.Exit(1)
	}
}

func dispatch(ctx context.Context, logger hclog.Logger, lim *rate.Limiter, rng *rand.Rand, client *api.Client, jobID string) error {
	for {
		select {
		case <-ctx.Done():
			return nil
		default:
		}

		r := lim.Reserve()
		if !r.OK() {
			continue
		}
		time.Sleep(r.Delay())

		if rng != nil {
			time.Sleep(time.Duration(rng.IntN(1000)) * time.Millisecond)
		}

		_, _, err := client.Jobs().Dispatch(jobID, nil, nil, "", nil)
		if err != nil {
			metrics.IncrCounter([]string{"dispatches_error"}, 1)
			logger.Error("failed to dispatch job", "error", err)
			continue
		}
		metrics.IncrCounter([]string{"dispatches"}, 1)
	}
}
