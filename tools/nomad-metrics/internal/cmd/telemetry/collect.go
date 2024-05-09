// Copyright (c) HashiCorp, Inc.
// SPDX-License-Identifier: MPL-2.0

package telemetry

import (
	"context"
	"flag"
	"fmt"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"github.com/hashicorp/go-hclog"
	"github.com/hashicorp/nomad-bench/nomad-metrics/internal/collector"
	"github.com/hashicorp/nomad-bench/nomad-metrics/internal/config"
	"github.com/hashicorp/nomad-bench/nomad-metrics/internal/log"
	"github.com/hashicorp/nomad-bench/nomad-metrics/internal/metadata"
	"github.com/hashicorp/nomad/helper/uuid"
	"github.com/mitchellh/cli"
)

type CollectCommand struct {
	UI *cli.BasicUi
}

func (c *CollectCommand) Help() string {
	helpText := `
Usage: nomad-metrics telemetry collect [options]

  Collect triggers scraping of the specified Nomad agent metric endpoints. All
  the collected data is written locally to disk.

Scrape Options:

  -scrape-name=<name>
    A custom, human readable name for this collection run that will be stored
    in the metadata file.

  -scrape-interval=<duration>
    The interval between each scrape of the Nomad agent API for telemetry. This
    is specified as a time duration such as "1s" and defaults to "5s".

  -scrape-duration=<duration>
    The total duration to scrape as a time duration such as "10m". The default
    of "0" means the process will scrape indefinitely until the user interrupts
    the process.

Nomad Options:

  -nomad-address=<addr>
    The Nomad HTTP API endpoints to scrape. This can be supplied multiple times
    to scrape from multiple Nomad agents. Defaults to "http://127.0.0.1:4646".

  -nomad-token=<token>
    The SecretID of an ACL token to use to authenticate API requests with.

  -nomad-region=<region>
    The Nomad region identifier to connect.

  -nomad-tls-client-cert=<path>
    Path to a PEM encoded client certificate for TLS authentication to the Nomad
    agent.

  -nomad-tls-client-key=<path>
    Path to an unencrypted PEM encoded private key matching the client certificate.

  -nomad-tls-insecure
    Do not verify the TLS certificate.

  -nomad-tls-server-name=<name>
    The server name to use as the SNI host when connecting via TLS.

  -nomad-tls-ca-cert=<path>
    Path to a directory of PEM encoded CA cert files to verify the Nomad server
    SSL certificate.

Log Options:

  -log-level=<level>
    Specify the verbosity level of the processes logs. Valid values include
    DEBUG, INFO, and WARN, in decreasing order of verbosity. The default is
    DEBUG.

  -log-json
    Output logs in a JSON format. The default is false.
`
	return strings.TrimSpace(helpText)
}

func (c *CollectCommand) Synopsis() string {
	return "Scrape telemetry data from Nomad agents and store locally"
}

func (c *CollectCommand) Name() string { return LoadCommandName }

func (c *CollectCommand) Run(args []string) int {

	flagSet := flag.NewFlagSet(c.Name(), flag.ContinueOnError)
	flagSet.Usage = func() { c.UI.Output(c.Help()) }

	cfg := config.DefaultCollect()

	flagSet.Var(&cfg.Nomad.Addresses, "nomad-address", "")
	flagSet.StringVar(&cfg.Nomad.Region, "nomad-region", "", "")
	flagSet.StringVar(&cfg.Nomad.Token, "nomad-token", "", "")
	flagSet.StringVar(&cfg.Nomad.TLS.CACert, "nomad-tls-ca-cert", "", "")
	flagSet.StringVar(&cfg.Nomad.TLS.ClientCert, "nomad-tls-client-cert", "", "")
	flagSet.StringVar(&cfg.Nomad.TLS.ClientKey, "nomad-tls-client-key", "", "")
	flagSet.StringVar(&cfg.Nomad.TLS.ServerName, "nomad-tls-server-name", "", "")
	flagSet.BoolVar(&cfg.Nomad.TLS.Insecure, "nomad-tls-insecure", false, "")

	flagSet.StringVar(&cfg.Scrape.Name, "scrape-name", "", "")
	flagSet.Var((config.FuncDurationVar)(func(d time.Duration) error {
		cfg.Scrape.Interval = d
		return nil
	}), "scrape-interval", "")
	flagSet.Var((config.FuncDurationVar)(func(d time.Duration) error {
		cfg.Scrape.Duration = d
		return nil
	}), "scrape-duration", "")

	flagSet.StringVar(&cfg.Log.Level, "log-level", "debug", "")
	flagSet.BoolVar(&cfg.Log.JSON, "log-json", false, "")

	if err := flagSet.Parse(args); err != nil {
		return 1
	}

	logger := log.NewLogger(cfg.Log)

	metricDir := "nomad-metrics-" + uuid.Short()

	if err := os.Mkdir(metricDir, os.ModePerm); err != nil {
		c.UI.Error(fmt.Sprintf("failed to create metric directory: %v", err))
		return 1
	}

	if len(cfg.Nomad.Addresses) == 0 {
		cfg.Nomad.Addresses = []string{"http://127.0.0.1:4646"}
	}
	if cfg.Scrape.Name == "" {
		cfg.Scrape.Name = metricDir
	}

	collectors := make([]*collector.Collector, len(cfg.Nomad.Addresses))

	for i, addr := range cfg.Nomad.Addresses {
		collector, err := collector.New(metricDir, addr, logger, cfg)
		if err != nil {
			c.UI.Error(fmt.Sprintf("failed to create metric directory: %v", err))
			return 1
		}
		collectors[i] = collector
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
		return 1
	} else {
		logger.Info("successfully wrote metadata", "file", metadataFile.FilePath())
		return 0
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
