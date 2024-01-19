package collector

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"time"

	"github.com/hashicorp/go-hclog"
	"github.com/hashicorp/nomad/api"
	"github.com/hashicorp/team-nomad/tools/nomad-metrics/internal/config"
	"github.com/hashicorp/team-nomad/tools/nomad-metrics/internal/write"
)

type Collector struct {
	agentInfo *api.AgentSelf
	agentName string

	dir         string
	logger      hclog.Logger
	nomadClient *api.Client
	scrapeCfg   *config.Scrape
}

func New(basePath, addr string, logger hclog.Logger, cfg *config.Config) (*Collector, error) {

	defaultConfig := api.DefaultConfig()
	defaultConfig.Address = addr

	if cfg.Nomad.Region != "" {
		defaultConfig.Address = cfg.Nomad.Region
	}
	if cfg.Nomad.Token != "" {
		defaultConfig.SecretID = cfg.Nomad.Token
	}
	if cfg.Nomad.TLS != nil {
		if cfg.Nomad.TLS.CACert != "" {
			defaultConfig.TLSConfig.CACert = cfg.Nomad.TLS.CACert
		}
		if cfg.Nomad.TLS.ClientKey != "" {
			defaultConfig.TLSConfig.ClientKey = cfg.Nomad.TLS.ClientKey
		}
		if cfg.Nomad.TLS.ServerName != "" {
			defaultConfig.TLSConfig.TLSServerName = cfg.Nomad.TLS.ServerName
		}
		if cfg.Nomad.TLS.ClientCert != "" {
			defaultConfig.TLSConfig.ClientCert = cfg.Nomad.TLS.ClientCert
		}
		if cfg.Nomad.TLS.Insecure {
			defaultConfig.TLSConfig.Insecure = cfg.Nomad.TLS.Insecure
		}
	}

	nomadClient, err := api.NewClient(defaultConfig)
	if err != nil {
		return nil, fmt.Errorf("failed to generate Nomad client: %w", err)
	}

	agentInfo, err := nomadClient.Agent().Self()
	if err != nil {
		return nil, fmt.Errorf("failed to query Nomad agent self: %w", err)
	}

	metricDir := filepath.Join(basePath, agentInfo.Member.Name)

	if err := os.Mkdir(metricDir, os.ModePerm); err != nil {
		return nil, fmt.Errorf("failed to create base metric directory: %w", err)
	}

	return &Collector{
		agentInfo:   agentInfo,
		agentName:   agentInfo.Member.Name,
		dir:         metricDir,
		logger:      logger.Named("collector").With("agent", agentInfo.Member.Name),
		nomadClient: nomadClient,
		scrapeCfg:   cfg.Scrape,
	}, nil
}

func (c *Collector) AgentInfo() (*api.AgentSelf, string) { return c.agentInfo, c.agentName }

func (c *Collector) Run(ctx context.Context) {

	t := time.NewTicker(c.scrapeCfg.Interval)
	defer t.Stop()

	c.logger.Info("starting collector")

	for {
		select {
		case <-ctx.Done():
			c.logger.Info("shutting down collector")
			return
		case <-t.C:

			metricBytes, err := c.nomadClient.Operator().Metrics(&api.QueryOptions{})
			if err != nil {
				c.logger.Error("failed to query Nomad metrics", "error", err)
				continue
			}

			file := filepath.Join(c.dir, strconv.FormatInt(time.Now().UnixNano(), 10)) + ".json"

			if err := write.JSON(c.logger, file, metricBytes); err != nil {
				c.logger.Error("failed to create metric file", "error", err)
			} else {
				c.logger.Info("successfully wrote metrics to file", "file", file)
			}
		}
	}
}
