package influxdb

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"github.com/hashicorp/go-hclog"
	"github.com/hashicorp/nomad/api"
	"github.com/hashicorp/team-nomad/tools/nomad-metrics/internal/write"
	"github.com/influxdata/line-protocol/v2/lineprotocol"
)

type Transformer struct {
	logger hclog.Logger
	path   string

	fileList []string
	metrics  map[string]*metric
}

type metric struct {
	labelKeys []string
	lpe       *lineprotocol.Encoder
}

func NewTransformer(logger hclog.Logger, path string) *Transformer {
	return &Transformer{
		logger:  logger.Named("transformer.influxdb"),
		path:    path,
		metrics: make(map[string]*metric),
	}
}

func (t *Transformer) Run() error {

	t.logger.Info("starting data transformation", "source_path", t.path)

	if err := t.generateFileList(); err != nil {
		return fmt.Errorf("failed to generate file listing: %w", err)
	}

	if err := t.processFiles(); err != nil {
		return fmt.Errorf("failed to process JSON files: %w", err)
	}

	if err := t.writeLineProtocolData(); err != nil {
		return fmt.Errorf("failed to write line protocol files: %w", err)
	}
	return nil
}

func (t *Transformer) generateFileList() error {
	return filepath.Walk(t.path, func(path string, info os.FileInfo, err error) error {
		if !info.IsDir() &&
			!strings.HasSuffix(info.Name(), "metadata.json") &&
			strings.HasSuffix(info.Name(), ".json") {
			t.fileList = append(t.fileList, path)
		}
		return nil
	})
}

func (t *Transformer) processFiles() error {

	for _, fileName := range t.fileList {

		pathParts := strings.Split(fileName, "/")
		if len(pathParts) != 3 {
			return fmt.Errorf("unsupported filename found: %q", fileName)
		}

		nomadAgentNameSplit := strings.Split(pathParts[1], ".")
		if len(nomadAgentNameSplit) != 2 {
			return fmt.Errorf("unsupported agent name found: %q", pathParts[1])
		}

		fileBytes, err := os.ReadFile(fileName)
		if err != nil {
			return fmt.Errorf("failed to read file: %w", err)
		}

		if err := t.transformFile(fileBytes, nomadAgentNameSplit[0], nomadAgentNameSplit[1]); err != nil {
			return fmt.Errorf("failed to transform file: %w", err)
		}
	}

	return nil
}

func (t *Transformer) writeLineProtocolData() error {

	dstPath := filepath.Join(t.path, "influxdb")

	if err := os.MkdirAll(dstPath, os.ModePerm); err != nil {
		return fmt.Errorf("failed to create influx data dir: %w", err)
	}

	t.logger.Info("starting write of transformed data", "dest_path", dstPath)

	for metricName, processedMetricData := range t.metrics {
		metricName = strings.ReplaceAll(metricName, ".", "_")

		fileAb, err := filepath.Abs(filepath.Join(dstPath, metricName+".influx.lp"))
		if err != nil {
			return fmt.Errorf("failed to generate absolute path: %w", err)
		}

		if err := write.WriteBlob(fileAb, processedMetricData.lpe.Bytes()); err != nil {
			return fmt.Errorf("failed to write line protocol file: %w", err)
		}

		t.logger.Info("successfully wrote line protocol file", "file", fileAb)

	}
	return nil
}

func (t *Transformer) transformFile(data []byte, agentName, agentRegion string) error {

	var metricSummary api.MetricsSummary

	if err := json.Unmarshal(data, &metricSummary); err != nil {
		return fmt.Errorf("failed to unmarshal metric data: %w", err)
	}

	parsedTime, err := time.Parse("2006-01-02 15:04:05 -0700 MST", metricSummary.Timestamp)
	if err != nil {
		return fmt.Errorf("error parsing time: %w", err)
	}

	for _, counter := range metricSummary.Counters {

		t.ensureEncoderInitialized(counter.Name, counter.DisplayLabels)

		enc := t.metrics[counter.Name]
		enc.lpe.StartLine(counter.Name)

		t.encodeTags(enc, counter.DisplayLabels, agentName, agentRegion)

		enc.lpe.AddField("count", lineprotocol.MustNewValue(int64(counter.Count)))
		enc.lpe.AddField("rate", lineprotocol.MustNewValue(counter.Rate))
		enc.lpe.AddField("sum", lineprotocol.MustNewValue(counter.Sum))
		enc.lpe.AddField("sumsq", lineprotocol.MustNewValue(counter.SumSq))
		enc.lpe.AddField("min", lineprotocol.MustNewValue(counter.Min))
		enc.lpe.AddField("max", lineprotocol.MustNewValue(counter.Max))
		enc.lpe.AddField("mean", lineprotocol.MustNewValue(counter.Mean))

		enc.lpe.EndLine(parsedTime)

		if err := enc.lpe.Err(); err != nil {
			return fmt.Errorf("failed to encode line protocol data: %w", err)
		}
	}

	for _, gauges := range metricSummary.Gauges {

		t.ensureEncoderInitialized(gauges.Name, gauges.DisplayLabels)

		enc := t.metrics[gauges.Name]
		enc.lpe.StartLine(gauges.Name)

		t.encodeTags(enc, gauges.DisplayLabels, agentName, agentRegion)
		enc.lpe.AddField("value", lineprotocol.MustNewValue(float64(gauges.Value)))

		enc.lpe.EndLine(parsedTime)

		if err := enc.lpe.Err(); err != nil {
			return fmt.Errorf("failed to encode line protocol data: %w", err)
		}
	}

	for _, sample := range metricSummary.Samples {

		t.ensureEncoderInitialized(sample.Name, sample.DisplayLabels)

		enc := t.metrics[sample.Name]
		enc.lpe.StartLine(sample.Name)

		t.encodeTags(enc, sample.DisplayLabels, agentName, agentRegion)

		enc.lpe.AddField("rate", lineprotocol.MustNewValue(sample.Rate))
		enc.lpe.AddField("sum", lineprotocol.MustNewValue(sample.Sum))
		enc.lpe.AddField("stddev", lineprotocol.MustNewValue(sample.Stddev))
		enc.lpe.AddField("sumsq", lineprotocol.MustNewValue(sample.SumSq))
		enc.lpe.AddField("min", lineprotocol.MustNewValue(sample.Min))
		enc.lpe.AddField("max", lineprotocol.MustNewValue(sample.Max))
		enc.lpe.AddField("mean", lineprotocol.MustNewValue(sample.Mean))

		enc.lpe.EndLine(parsedTime)

		if err := enc.lpe.Err(); err != nil {
			return fmt.Errorf("failed to encode line protocol data: %w", err)
		}
	}
	return nil
}

func (t *Transformer) ensureEncoderInitialized(name string, labels map[string]string) {
	if _, ok := t.metrics[name]; !ok {
		t.metrics[name] = &metric{
			lpe: &lineprotocol.Encoder{},
		}
		for k := range labels {
			t.metrics[name].labelKeys = append(t.metrics[name].labelKeys, k)
		}
		t.metrics[name].labelKeys = append(t.metrics[name].labelKeys, "agent_name")
		t.metrics[name].labelKeys = append(t.metrics[name].labelKeys, "agent_region")
		sort.Strings(t.metrics[name].labelKeys)
	}
}

func (t *Transformer) encodeTags(m *metric, labels map[string]string, name, region string) {
	for _, labelKey := range m.labelKeys {
		switch labelKey {
		case "agent_name":
			m.lpe.AddTag(labelKey, name)
		case "agent_region":
			m.lpe.AddTag(labelKey, region)
		default:
			displayValue, _ := labels[labelKey]
			m.lpe.AddTag(labelKey, displayValue)
		}
	}
}
