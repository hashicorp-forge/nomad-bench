package log

import (
	"github.com/hashicorp/go-hclog"
	"github.com/hashicorp/nomad-bench/nomad-metrics/internal/config"
)

func NewLogger(cfg *config.Log) hclog.Logger {
	return hclog.New(&hclog.LoggerOptions{
		Name:       "nomad-metrics",
		Level:      hclog.LevelFromString(cfg.Level),
		JSONFormat: cfg.JSON,
	})
}
