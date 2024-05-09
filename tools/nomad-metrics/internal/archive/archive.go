// Copyright (c) HashiCorp, Inc.
// SPDX-License-Identifier: MPL-2.0

package archive

import (
	"archive/tar"
	"compress/gzip"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/s3/s3manager"
	"github.com/hashicorp/go-hclog"
	"github.com/hashicorp/nomad-bench/nomad-metrics/internal/config"
)

type Archive struct {
	cfg        *config.Archive
	logger     hclog.Logger
	s3Uploader *s3manager.Uploader

	tmpDir string
}

func New(cfg *config.Archive, logger hclog.Logger) (*Archive, error) {

	region := "us-west-1"
	if cfg.AWS.Region != "" {
		region = cfg.AWS.Region
	}

	awsSession, err := session.NewSession(&aws.Config{Region: aws.String(region)})
	if err != nil {
		return nil, fmt.Errorf("failed to generate AWS session: %w", err)
	}

	return &Archive{
		cfg:        cfg,
		logger:     logger.Named("archive"),
		s3Uploader: s3manager.NewUploader(awsSession),
	}, nil
}

func (a *Archive) Create() error {

	// The InfluxDB go-client does not support backups, and their stance is to
	// use the CLI. Therefore, look this up, as we will need to exec this to
	// perform the dump.
	if _, err := exec.LookPath("influx"); err != nil {
		return errors.New("influx CLI not found")
	}

	// Create a temp directory that we will use to stage all the data before
	// uploading it
	tmpDir, err := os.MkdirTemp("", "nomad-bench-archive-")
	if err != nil {
		return fmt.Errorf("failed to create tmp directory: %w", err)
	}
	a.tmpDir = tmpDir

	// Remove the temporary directory when this function exits. If this fails,
	// log, so that the operator can remove this manually if they want.
	defer func() {
		if err := os.RemoveAll(tmpDir); err != nil {
			a.logger.Error("failed to remove temporary directory", "error", err)
		} else {
			a.logger.Info("successfully removed temporary directory", "directory", a.tmpDir)
		}
	}()

	if err := a.prepareArtifacts(); err != nil {
		return err
	}

	return a.uploadArtifacts()
}

func (a *Archive) prepareArtifacts() error {

	if a.cfg.LocalTelemetryPath != "" {
		if err := a.zipNomadMetricsDir(); err != nil {
			return fmt.Errorf("failed to compress local metrics: %w", err)
		}
	}

	if a.cfg.InfluxDB.Bucket != "" && a.cfg.InfluxDB.Organization != "" {
		if err := a.getInfluxDBDump(); err != nil {
			return fmt.Errorf("failed to backup InfluxDB bucket: %w", err)
		}
	}

	return nil
}

func (a *Archive) zipNomadMetricsDir() error {

	if _, err := os.Stat(a.cfg.LocalTelemetryPath); err != nil {
		return fmt.Errorf("failed to stat local telemetry path: %w", err)
	}

	if err := os.Mkdir(filepath.Join(a.tmpDir, "nomad-metrics"), os.ModePerm); err != nil {
		return fmt.Errorf("failed to create temporary dir: %w", err)
	}

	// create the archive
	fh, err := os.Create(filepath.Join(a.tmpDir, "nomad-metrics", "dump.tar.gz"))
	if err != nil {
		return fmt.Errorf("failed to create destination archive: %w", err)
	}
	defer a.deferCloser(fh.Close)

	zz := gzip.NewWriter(fh)
	defer a.deferCloser(zz.Close)

	tw := tar.NewWriter(zz)
	defer a.deferCloser(tw.Close)

	return filepath.Walk(a.cfg.LocalTelemetryPath, func(file string, fi os.FileInfo, err error) error {
		if err != nil {
			return err
		}

		if !fi.Mode().IsRegular() {
			return nil
		}

		header, err := tar.FileInfoHeader(fi, fi.Name())
		if err != nil {
			return err
		}

		// remove leading path to the src, so files are relative to the archive
		path := strings.ReplaceAll(file, a.cfg.LocalTelemetryPath, "")
		path = strings.TrimPrefix(path, string(filepath.Separator))

		header.Name = path

		if err := tw.WriteHeader(header); err != nil {
			return err
		}

		// copy the file contents
		f, err := os.Open(file)
		if err != nil {
			return err
		}

		if _, err := io.Copy(tw, f); err != nil {
			return err
		}

		defer a.deferCloser(f.Close)
		a.logger.Info("successfully compressed metrics file", "src", fi.Name(), "tmp_dst", fh.Name())
		return nil
	})
}

func (a *Archive) getInfluxDBDump() error {

	cmd := exec.Command("influx", "backup",
		"--host="+a.cfg.InfluxDB.ServerURL,
		"--token="+a.cfg.InfluxDB.AuthToken,
		"--org-id="+a.cfg.InfluxDB.Organization,
		"--bucket="+a.cfg.InfluxDB.Bucket,
		"--skip-verify",
		filepath.Join(a.tmpDir, "influx"),
	)

	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to run InfluxDB backup command: %w", err)
	}

	a.logger.Info("successfully backed up InfluxDB",
		"influxdb_bucket", a.cfg.InfluxDB.Bucket,
		"influxdb_org_id", a.cfg.InfluxDB.Organization,
		"tmp_dst", filepath.Join(a.tmpDir, "influx"),
	)
	return nil
}

func (a *Archive) uploadArtifacts() error {

	return filepath.Walk(a.tmpDir, func(file string, fi os.FileInfo, err error) error {
		if err != nil {
			return err
		}

		if !fi.Mode().IsRegular() {
			return nil
		}

		openFile, err := os.Open(file)
		if err != nil {
			return fmt.Errorf("failed to open file: %w", err)
		}

		fileSplit := strings.Split(file, "/")
		key := filepath.Join(a.cfg.S3.Key, fileSplit[len(fileSplit)-2], fi.Name())

		uploadOutput, err := a.s3Uploader.Upload(&s3manager.UploadInput{
			Bucket: aws.String(a.cfg.S3.Bucket),
			Key:    aws.String(key),
			Body:   openFile,
		})
		if err != nil {
			return fmt.Errorf("failed to upload file to AWS S3: %w", err)
		}

		a.logger.Info("successfully uploaded file to AWS S3", "url", uploadOutput.Location)
		return nil
	})
}

func (a *Archive) deferCloser(fn func() error) {
	if err := fn(); err != nil {
		a.logger.Error("failed to call defer function close", "error", err)
	}
}
