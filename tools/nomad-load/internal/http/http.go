package http

import (
	"bytes"
	"fmt"
	"net"
	"net/http"
	"time"

	"github.com/hashicorp/go-hclog"
	"github.com/hashicorp/go-metrics"
	"github.com/hashicorp/go-msgpack/codec"
)

type Server struct {
	log hclog.Logger
	ln  net.Listener
	mux *http.ServeMux
	srv *http.Server

	inMemorySink *metrics.InmemSink
}

func NewServer(logger hclog.Logger, addr, port string, sink *metrics.InmemSink) (*Server, error) {

	srv := &Server{
		log:          logger.Named("http_server"),
		mux:          http.NewServeMux(),
		inMemorySink: sink,
	}

	// Setup our handlers.
	srv.mux.HandleFunc("/v1/metrics", srv.wrap(srv.getMetrics))

	// Configure the HTTP server to the most basic level.
	srv.srv = &http.Server{
		Addr:         fmt.Sprintf("%s:%v", addr, port),
		Handler:      srv.mux,
		ReadTimeout:  5 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  15 * time.Second,
	}

	return srv, nil

}

func (s *Server) Server() *http.Server { return s.srv }

// wrap is a helper for all HTTP handler functions providing common
// functionality including logging and error handling.
func (s *Server) wrap(handler func(w http.ResponseWriter, r *http.Request) (interface{}, error)) func(w http.ResponseWriter, r *http.Request) {
	f := func(w http.ResponseWriter, r *http.Request) {

		start := time.Now()

		// Defer a function which allows us to log the time taken to fulfill
		// the HTTP request.
		defer func() {
			s.log.Trace("request complete", "method", r.Method,
				"path", r.URL, "duration", time.Since(start))
		}()

		// Handle the request, allowing us to the get response object and any
		// error from the endpoint.
		obj, err := handler(w, r)
		if err != nil {
			s.handleHTTPError(w, r, err)
			return
		}

		// If we have a response object, encode it.
		if obj != nil {
			var buf bytes.Buffer

			enc := codec.NewEncoder(&buf, &codec.JsonHandle{HTMLCharsAsIs: true})

			// Encode the object. If we fail to do this, handle the error so
			// that this can be passed to the operator.
			err := enc.Encode(obj)
			if err != nil {
				s.handleHTTPError(w, r, err)
				return
			}

			//  Set the content type header and write the data to the HTTP
			//  reply.
			w.Header().Set("Content-Type", "application/json")
			_, _ = w.Write(buf.Bytes())
		}
	}

	return f
}

// handleHTTPError is used to handle HTTP handler errors within the wrap func.
// It sets response headers where required and ensure appropriate errors are
// logged.
func (s *Server) handleHTTPError(w http.ResponseWriter, r *http.Request, err error) {

	// Start with a default internal server error and the error message
	// that was returned.
	code := http.StatusInternalServerError
	errMsg := err.Error()

	// If the error was a custom codedError update the response code to
	// that of the wrapped error.
	if codedErr, ok := err.(codedError); ok {
		code = codedErr.Code()
	}

	// Write the status code header.
	w.WriteHeader(code)

	// Write the response body. If we get an error, log this as it will
	// provide some operator insight if this happens regularly.
	if _, wErr := w.Write([]byte(errMsg)); wErr != nil {
		s.log.Error("failed to write response error", "error", wErr)
	}
	s.log.Error("request failed", "method", r.Method, "path", r.URL, "error", errMsg, "code", code)
}
