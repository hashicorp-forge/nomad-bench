package metadata

import (
	"encoding/json"
	"fmt"
	"path/filepath"
	"time"

	"github.com/hashicorp/go-hclog"
	"github.com/hashicorp/nomad-bench/nomad-metrics/internal/write"
	"github.com/hashicorp/nomad/api"
)

type Metadata struct {
	Agents    map[string]*api.AgentSelf
	Name      string
	Path      string
	StartTime time.Time
	EndTime   time.Time

	logger hclog.Logger
}

func New(logger hclog.Logger, path, name string) *Metadata {
	return &Metadata{
		Agents:    make(map[string]*api.AgentSelf),
		Name:      name,
		Path:      path,
		StartTime: time.Now().UTC(),
		logger:    logger.Named("metadata"),
	}
}

func (m *Metadata) RecordEndTime(end time.Time) { m.EndTime = end }

func (m *Metadata) RecordAgentSelf(self *api.AgentSelf, name string) { m.Agents[name] = self }

func (m *Metadata) Write() error {
	byteArray, err := json.Marshal(m)
	if err != nil {
		return fmt.Errorf("failed to marshal JSON: %w", err)
	}
	return write.JSON(m.logger, m.FilePath(), byteArray)
}

func (m *Metadata) FilePath() string { return filepath.Join(m.Path, "metadata.json") }
