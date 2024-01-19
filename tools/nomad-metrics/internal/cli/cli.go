package cli

import (
	"context"
	"flag"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/hashicorp/go-hclog"
	"github.com/hashicorp/nomad/helper/uuid"
	"github.com/hashicorp/team-nomad/tools/nomad-metrics/internal/collector"
	"github.com/hashicorp/team-nomad/tools/nomad-metrics/internal/config"
	"github.com/hashicorp/team-nomad/tools/nomad-metrics/internal/metadata"
)

func Run() {

	cfg := config.Default()

	flag.Var(&cfg.Nomad.Addresses, "nomad-address", "The Nomad HTTP API endpoints to scrape.")
	flag.StringVar(&cfg.Nomad.Region, "nomad-region", "", "The Nomad region identifier to connect.")
	flag.StringVar(&cfg.Nomad.Token, "nomad-token", "", "The ACL token to use for secured endpoint calls.")
	flag.StringVar(&cfg.Nomad.TLS.CACert, "nomad-tls-ca-cert", "", "Path to a PEM encoded CA cert file.")
	flag.StringVar(&cfg.Nomad.TLS.ClientCert, "nomad-tls-client-cert", "", "Path to a PEM encoded client certificate.")
	flag.StringVar(&cfg.Nomad.TLS.ClientKey, "nomad-tls-client-key", "", "Path to an unencrypted PEM encoded private key matching the client certificate.")
	flag.StringVar(&cfg.Nomad.TLS.ServerName, "nomad-tls-server-name", "", "The server name to use as the SNI host.")
	flag.BoolVar(&cfg.Nomad.TLS.Insecure, "nomad-tls-insecure", false, "Do not verify the TLS certificate.")

	flag.StringVar(&cfg.Scrape.Name, "scrape-name", "", "Custom identifier name for this collection run.")
	flag.Var((config.FuncDurationVar)(func(d time.Duration) error {
		cfg.Scrape.Interval = d
		return nil
	}), "scrape-interval", "The interval between scrapes.")
	flag.Var((config.FuncDurationVar)(func(d time.Duration) error {
		cfg.Scrape.Duration = d
		return nil
	}), "scrape-duration", "The total duration to scrape for.")

	flag.Parse()

	logger := hclog.New(&hclog.LoggerOptions{
		Name:  "nomad-metrics",
		Level: hclog.Debug,
	})

	metricDir := "nomad-metrics-" + uuid.Short()

	if err := os.Mkdir(metricDir, os.ModePerm); err != nil {
		logger.Error("failed to create metric directory", "error", err)
		os.Exit(1)
	}

	if len(cfg.Nomad.Addresses) == 0 {
		cfg.Nomad.Addresses = []string{"http://127.0.0.1:4646"}
	}
	if cfg.Scrape.Name == "" {
		cfg.Scrape.Name = metricDir
	}

	collectors := make([]*collector.Collector, len(cfg.Nomad.Addresses))

	for i, addr := range cfg.Nomad.Addresses {
		c, err := collector.New(metricDir, addr, logger, cfg)
		if err != nil {
			logger.Error("failed to build collector", "error", err)
			os.Exit(1)
		}
		collectors[i] = c
	}

	ctx, cancel := context.WithCancel(context.Background())
	if cfg.Scrape.Duration > 0 {
		ctx, cancel = context.WithTimeout(ctx, cfg.Scrape.Duration)
	}

	metadataFile := metadata.New(logger, metricDir, cfg.Scrape.Name)

	logger.Info("starting metric collectors",
		"addresses", cfg.Nomad.Addresses, "scrape_interval",
		cfg.Scrape.Interval, "scrape_duration", cfg.Scrape.Duration)

	for _, nomadCollector := range collectors {
		metadataFile.RecordAgentSelf(nomadCollector.AgentInfo())
		go nomadCollector.Run(ctx)
	}

	waitForExit(ctx, logger)
	cancel()

	metadataFile.RecordEndTime(time.Now().UTC())
	if err := metadataFile.Write(); err != nil {
		logger.Error("failed to write metadata", "error", err)
	} else {
		logger.Info("successfully wrote metadata", "file", metadataFile.FilePath())
	}
}

func waitForExit(ctx context.Context, logger hclog.Logger) {

	sigs := make(chan os.Signal, 1)
	signal.Notify(sigs, syscall.SIGINT, syscall.SIGTERM)

	for {
		select {
		case signalRec := <-sigs:
			logger.Info("received signal", "signal", signalRec.String())
			return
		case <-ctx.Done():
			logger.Info("scrape duration timeout reached, exiting")
			return
		}
	}
}
