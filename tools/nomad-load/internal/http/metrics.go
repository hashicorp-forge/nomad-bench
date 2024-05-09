// Copyright (c) HashiCorp, Inc.
// SPDX-License-Identifier: MPL-2.0

package http

import (
	"net/http"
	"sync"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
	// Only create the prometheus handler once
	promHandler http.Handler
	promOnce    sync.Once
)

func (s *Server) getMetrics(w http.ResponseWriter, r *http.Request) (interface{}, error) {

	// Only allow GET requests on this endpoint.
	if r.Method != http.MethodGet {
		return nil, newCodedError(http.StatusMethodNotAllowed, errInvalidMethod)
	}

	if format := r.URL.Query().Get("format"); format == "prometheus" {
		s.getPrometheusMetrics().ServeHTTP(w, r)
		return nil, nil
	}
	return s.inMemorySink.DisplayMetrics(w, r)
}

// getPrometheusMetrics is the getMetrics handler when the caller wishes to
// view them in Prometheus format.
func (s *Server) getPrometheusMetrics() http.Handler {
	promOnce.Do(func() {
		handlerOptions := promhttp.HandlerOpts{
			ErrorLog:           s.log.Named("prometheus").StandardLogger(nil),
			ErrorHandling:      promhttp.ContinueOnError,
			DisableCompression: true,
		}
		promHandler = promhttp.HandlerFor(prometheus.DefaultGatherer, handlerOptions)
	})
	return promHandler
}
