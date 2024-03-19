package main

import (
	"context"
	"flag"
	"fmt"
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

	"github.com/hashicorp/nomad-bench/tools/nomad-load/internal"
	"github.com/hashicorp/nomad-bench/tools/nomad-load/version"
)

var (
	nomadAddr = flag.String("nomad-addr", "", "The address of the Nomad server")
	httpAddr  = flag.String("http-addr", "0.0.0.0", "The address to bind the HTTP server to")
	httpPort  = flag.String("http-port", "8080", "The port to bind the HTTP server to")
	reqRate   = flag.Float64("rate", 10, "The rate of constant job dispatches per second")
	burstRate = flag.Int("burst", 1, "The burst rate of constant job dispatches")
	workers   = flag.Int("workers", 10*runtime.NumCPU(), "The number of workers to use")
	job       = flag.String("job", "batch", "What job to dispatch. Available options are: batch (default), service, system, and periodic")
	logLevel  = flag.String("log-level", "DEBUG", "The log level to use")
)

func main() {
	flag.Parse()

	flag.Usage = func() {
		fmt.Fprintf(os.Stderr, `Usage: ./nomad-load [options] [command]

Commands:
  constant   Dispatches a constant rate of jobs
  sometimes  [TODO] Dispatches jobs at with a random delay

  version    Prints the version of the tool

Options:
`)
		flag.PrintDefaults()
	}

	logger := hclog.NewInterceptLogger(&hclog.LoggerOptions{
		Name:            "nomad-load",
		Level:           hclog.LevelFromString(*logLevel),
		IncludeLocation: true,
	})

	command := flag.Args()
	if len(command) != 1 {
		flag.Usage()
		os.Exit(1)
	}

	// Parse job flag
	var jobSpec string
	switch *job {
	case "batch":
		jobSpec = internal.DispatchBatchJob
	default:
		logger.Error("invalid job type", "job", *job)
		os.Exit(1)
	}

	var lim *rate.Limiter
	switch command[0] {
	case "constant":
		lim = rate.NewLimiter(rate.Limit(*reqRate), *burstRate)
	case "version":
		fmt.Printf("Version: %s\nCommit: %s\n", version.VERSION, version.GITCOMMIT)
		os.Exit(0)
	default:

	}

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
	metrics.NewGlobal(metrics.DefaultConfig("nomad-load"), promSink)

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

	r := strings.NewReader(jobSpec)
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

	// Start goroutines to dispatch job.
	stdLogger := logger.StandardLogger(&hclog.StandardLoggerOptions{InferLevels: true})
	stdLogger.Printf("[INFO] dispatching %v jobs at a rate of %v per second with bursts up to %v", *workers, *reqRate, *burstRate)
	for i := 0; i < *workers; i++ {
		g.Go(func() error {
			return dispatch(ctx, logger, lim, c, *j.ID)
		})
	}

	// Wait for results.
	err = g.Wait()
	if err != nil {
		logger.Error(err.Error())
		os.Exit(1)
	}
}

func dispatch(ctx context.Context, logger hclog.Logger, lim *rate.Limiter, client *api.Client, jobID string) error {
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

		_, _, err := client.Jobs().Dispatch(jobID, nil, nil, "", nil)
		if err != nil {
			metrics.IncrCounter([]string{"dispatches_error"}, 1)
			logger.Error("failed to dispatch job", "error", err)
			continue
		}
		metrics.IncrCounter([]string{"dispatches"}, 1)
	}
}
