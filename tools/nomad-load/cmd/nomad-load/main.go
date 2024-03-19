package main

import (
	"context"
	"flag"
	"fmt"
	"net/http"
	"os"
	"runtime"
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

	"github.com/hashicorp/nomad-bench/tools/nomad-load/version"
)

var (
	nomadAddr = flag.String("nomad-addr", "", "The address of the Nomad server")
	httpAddr  = flag.String("http-addr", "0.0.0.0", "The address to bind the HTTP server to")
	httpPort  = flag.String("http-port", "8080", "The port to bind the HTTP server to")
	reqRate   = flag.Float64("rate", 10, "The rate of job dispatches per second")
	workers   = flag.Int("workers", 10*runtime.NumCPU(), "The number of workers to use")
	duration  = flag.Duration("duration", time.Minute, "The duration to run the test for")
	logLevel  = flag.String("log-level", "DEBUG", "The log level to use")
)

func main() {
	flag.Parse()

	flag.Usage = func() {
		fmt.Fprintf(os.Stderr, `Usage: ./nomad-load [options] pathToJobfile

Options:
`)
		flag.PrintDefaults()
	}

	logger := hclog.NewInterceptLogger(&hclog.LoggerOptions{
		Name:            "nomad-load",
		Level:           hclog.LevelFromString(*logLevel),
		IncludeLocation: true,
	})

	arg := flag.Args()
	if len(arg) != 1 {
		flag.Usage()
		os.Exit(1)
	}

	if arg[0] == "version" {
		fmt.Printf("Version: %s\nCommit: %s\n", version.VERSION, version.GITCOMMIT)
		os.Exit(0)
	}

	jobFilePath := arg[0]

	jobFile, err := os.Open(jobFilePath)
	if err != nil {
		logger.Error(err.Error())
		os.Exit(1)
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
	ctx, cancel := context.WithTimeout(context.Background(), *duration)
	g, ctx := errgroup.WithContext(ctx)
	defer cancel()

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

	j, err := jobspec2.Parse("job.nomad.hcl", jobFile)
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
	logger.Info("dispatching %v jobs at a rate of %v per second for %v", *workers, *reqRate, *duration)
	l := rate.NewLimiter(rate.Limit(*reqRate), 1)
	for i := 0; i < *workers; i++ {
		g.Go(func() error {
			return dispatch(ctx, logger, l, c, *j.ID)
		})
	}

	// Wait for results.
	err = g.Wait()
	if err != nil {
		logger.Error(err.Error())
		os.Exit(1)
	}
}

func dispatch(ctx context.Context, logger hclog.Logger, l *rate.Limiter, client *api.Client, jobID string) error {
	for {
		select {
		case <-ctx.Done():
			return nil
		default:
		}

		r := l.Reserve()
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
