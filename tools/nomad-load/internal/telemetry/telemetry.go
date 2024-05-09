// Copyright (c) HashiCorp, Inc.
// SPDX-License-Identifier: MPL-2.0

package telemetry

import (
	"fmt"
	"time"

	"github.com/hashicorp/go-metrics"
	"github.com/hashicorp/go-metrics/prometheus"
)

// Setup is used to setup the telemetry sub-systems and returns the in-memory
// sink to be used in http configuration.
func Setup() (*metrics.InmemSink, error) {

	inm := metrics.NewInmemSink(1*time.Second, 1*time.Minute)
	metrics.DefaultInmemSignal(inm)

	metricsConf := metrics.DefaultConfig("nomad-load")

	var fanout metrics.FanoutSink

	// Configure the Prometheus sink.
	prometheusOpts := prometheus.PrometheusOpts{
		Expiration: 1 * time.Minute,
	}

	sink, err := prometheus.NewPrometheusSinkFrom(prometheusOpts)
	if err != nil {
		return nil, fmt.Errorf("failed to setup Promtheus sink: %v", err)
	}
	fanout = append(fanout, sink)

	// Add the in-memory sink to the fanout.
	fanout = append(fanout, inm)

	// Initialize the global sink.
	_, err = metrics.NewGlobal(metricsConf, fanout)
	if err != nil {
		return nil, fmt.Errorf("failed to setup global sink: %v", err)
	}
	return inm, nil
}
