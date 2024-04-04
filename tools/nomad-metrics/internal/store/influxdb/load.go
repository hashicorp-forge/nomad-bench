package influxdb

import (
	"bufio"
	"context"
	"crypto/tls"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/hashicorp/go-hclog"
	"github.com/hashicorp/nomad-bench/nomad-metrics/internal/config"
	influxdb2 "github.com/influxdata/influxdb-client-go/v2"
	"github.com/influxdata/influxdb-client-go/v2/api"
)

type Loader struct {
	batchWriter *batchWriter
	logger      hclog.Logger
	path        string

	fileList []string
}

func NewLoader(logger hclog.Logger, cfg *config.Load, path string) *Loader {

	writeAPIClient := influxdb2.NewClientWithOptions(
		cfg.InfluxDB.ServerURL,
		cfg.InfluxDB.AuthToken,
		influxdb2.DefaultOptions().SetTLSConfig(
			&tls.Config{
				InsecureSkipVerify: true,
			},
		)).
		WriteAPIBlocking(cfg.InfluxDB.Organization, cfg.InfluxDB.Bucket)

	logger = logger.Named("load.influxdb").
		With("influxdb_org", cfg.InfluxDB.Organization).
		With("influxdb_bucket", cfg.InfluxDB.Bucket)

	return &Loader{
		batchWriter: newBatchWriter(writeAPIClient, logger),
		path:        path,
		logger:      logger,
	}
}

func (l *Loader) Run() error {

	if err := l.generateFileList(); err != nil {
		return fmt.Errorf("failed to generate file listing: %w", err)
	}

	l.logger.Info("starting write of data", "src_path", l.path)

	if err := l.processFiles(); err != nil {
		return fmt.Errorf("failed to write data to InfluxDB: %w", err)
	}

	return nil
}

func (l *Loader) generateFileList() error {

	if _, err := os.Stat(l.path); err != nil {
		return fmt.Errorf("failed to stat directory: %w", err)
	}

	return filepath.Walk(l.path, func(path string, info os.FileInfo, err error) error {
		if !info.IsDir() && strings.HasSuffix(info.Name(), ".influx.lp") {
			l.fileList = append(l.fileList, path)
		}
		return nil
	})
}

func (l *Loader) processFiles() error {

	for _, fileName := range l.fileList {

		fileHandle, err := os.OpenFile(fileName, os.O_RDONLY, os.ModePerm)
		if err != nil {
			return fmt.Errorf("failed to open file: %w", err)
		}

		fileScanner := bufio.NewScanner(fileHandle)

		for fileScanner.Scan() {
			if err := l.batchWriter.add(fileScanner.Text()); err != nil {
				_ = fileHandle.Close()
				return err
			}
		}
		_ = fileHandle.Close()
	}

	if err := l.batchWriter.flush(); err != nil {
		return err
	}

	return nil
}

// batchWriter is responsible for batching the write to InfluxDB's API. This is
// a simple but efficient way to speed up data loading.
type batchWriter struct {
	logger hclog.Logger

	// n tracks the current number of line protocol entries stored that have not
	// been flushed and written to InfluxDB.
	n int

	// lim is the size limit of the batch writer. Once this threshold is
	// reached, the batch writer will write the store line protocol data to
	// InfluxDB. The current default value of 5000 was selected after some
	// quick testing of values 10, 100, 1000, 10000.
	lim int

	// writeClient is the instantiated InfluxDB client used to write line
	// protocol data for storage. This application is not expected to run
	// multiple write routines, so it is currently a blocking API client.
	writeClient api.WriteAPIBlocking

	// lines stores the current batch of line protocol data waiting to be
	// written to InfluxDB.
	lines []string
}

func newBatchWriter(c api.WriteAPIBlocking, logger hclog.Logger) *batchWriter {
	return &batchWriter{
		logger:      logger,
		lim:         5000,
		writeClient: c,
	}
}

func (b *batchWriter) add(l string) error {
	b.lines = append(b.lines, l)

	if b.n++; b.n >= b.lim {
		return b.flush()
	}
	return nil
}

func (b *batchWriter) flush() error {
	if err := b.writeClient.WriteRecord(context.Background(), b.lines...); err != nil {
		return fmt.Errorf("failed to write records to InfluxDB: %w", err)
	}

	b.logger.Info("successfully wrote records to InfluxDB", "count", b.n)

	b.n = 0
	b.lines = []string{}
	return nil
}
