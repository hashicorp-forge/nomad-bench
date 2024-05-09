// Copyright (c) HashiCorp, Inc.
// SPDX-License-Identifier: MPL-2.0

package config

import (
	"errors"
	"fmt"

	"github.com/hashicorp/go-multierror"
)

type Archive struct {
	LocalTelemetryPath string
	Store              string
	AWS                *AWS
	S3                 *AWSS3
	InfluxDB           *InfluxDB
	Log                *Log
}

type AWS struct {
	Region string
}

type AWSS3 struct {
	Bucket string
	Key    string
}

func (a *Archive) Validate() error {

	var mErr multierror.Error

	if a.S3 == nil {
		mErr.Errors = append(mErr.Errors, errors.New("AWS S3 configuration options required"))
	} else {
		if a.S3.Bucket == "" {
			mErr.Errors = append(mErr.Errors, errors.New("AWS S3 bucket required"))
		}
		if a.S3.Key == "" {
			mErr.Errors = append(mErr.Errors, errors.New("AWS S3 bucket key required"))
		}
	}

	switch a.Store {
	case DataStoreInfluxDB:
		if err := a.InfluxDB.validate(); err != nil {
			mErr.Errors = append(mErr.Errors, err)
		}
	case "":
		if a.LocalTelemetryPath == "" {
			mErr.Errors = append(mErr.Errors, errors.New("no telemetry data selected to archive"))
		}
	default:
		mErr.Errors = append(mErr.Errors, fmt.Errorf("unsupported data store: %q", a.Store))
	}

	return mErr.ErrorOrNil()
}
