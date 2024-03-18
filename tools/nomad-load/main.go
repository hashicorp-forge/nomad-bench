package main

import (
	"context"
	_ "embed"
	"flag"
	"os"
	"runtime"
	"strings"
	"time"

	"github.com/hashicorp/go-hclog"
	"github.com/hashicorp/go-metrics"
	"github.com/hashicorp/nomad/api"
	"github.com/hashicorp/nomad/jobspec2"
	"golang.org/x/sync/errgroup"
	"golang.org/x/time/rate"
)

const version = "0.0.1"

//go:embed assets/job.nomad.hcl
var defaultJob string

func main() {
	var nomadAddr, httpAddr, httpPort, logLevel string
	var reqRate float64
	var workers int

	flag.StringVar(&nomadAddr, "nomad-addr", "", "")
	flag.StringVar(&httpAddr, "bind", "0.0.0.0", "")
	flag.StringVar(&httpPort, "port", "8080", "")
	flag.StringVar(&logLevel, "log-level", "DEBUG", "")
	flag.Float64Var(&reqRate, "rate", 10, "")
	flag.IntVar(&workers, "workers", 10*runtime.NumCPU(), "")
	flag.Parse()

	logger := hclog.NewInterceptLogger(&hclog.LoggerOptions{
		Name:            "nomad-load",
		Level:           hclog.LevelFromString(logLevel),
		IncludeLocation: true,
	})

	// Create errgroup to watch goroutines.
	g, ctx := errgroup.WithContext(context.Background())

	// Initialize Nomad client and register test job.
	config := api.DefaultConfig()
	c, err := api.NewClient(config)
	if err != nil {
		logger.Error("failed to start Nomad client", "error", err)
		os.Exit(1)
	}

	r := strings.NewReader(defaultJob)
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
	l := rate.NewLimiter(rate.Limit(reqRate), 1)
	for i := 0; i < workers; i++ {
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
