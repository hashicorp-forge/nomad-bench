package telemetry

import (
	"flag"
	"fmt"
	"strings"
	"time"

	"github.com/hashicorp/nomad-bench/nomad-metrics/internal/config"
	"github.com/hashicorp/nomad-bench/nomad-metrics/internal/log"
	"github.com/hashicorp/nomad-bench/nomad-metrics/internal/store"
	"github.com/hashicorp/nomad-bench/nomad-metrics/internal/store/influxdb"
	"github.com/mitchellh/cli"
)

type TransformCommand struct {
	UI *cli.BasicUi
}

func (t *TransformCommand) Help() string {
	helpText := `
Usage: nomad-metrics telemetry transform [options] <path>

Transform Options:

  -store=<name>
    The name of the data store to transform the JSON data for. This dictates
    which format the resulting files use and the subdir in which they are
    written. This currently supports "influxdb" which is the default.

Log Options:

  -log-level=<level>
    Specify the verbosity level of the processes logs. Valid values include
    DEBUG, INFO, and WARN, in decreasing order of verbosity. The default is
    DEBUG.

  -log-json
    Output logs in a JSON format. The default is false.
`
	return strings.TrimSpace(helpText)
}

func (t *TransformCommand) Synopsis() string {
	return "Transform JSON telemetry data into a new format"
}

func (t *TransformCommand) Name() string { return LoadCommandName }

func (t *TransformCommand) Run(args []string) int {

	flagSet := flag.NewFlagSet(t.Name(), flag.ContinueOnError)
	flagSet.Usage = func() { t.UI.Output(t.Help()) }

	cfg := config.TransformDefault()

	flagSet.StringVar(&cfg.Store, "store", config.DataStoreInfluxDB, "")
	flagSet.StringVar(&cfg.Log.Level, "log-level", "debug", "")
	flagSet.BoolVar(&cfg.Log.JSON, "log-json", false, "")

	if err := flagSet.Parse(args); err != nil {
		return 1
	}

	if len(flagSet.Args()) != 1 {
		t.UI.Error(fmt.Sprintf("expected one argument, got %v", len(flagSet.Args())))
		return 1
	}

	if err := cfg.Validate(); err != nil {
		t.UI.Error(fmt.Sprintf("failed to validate config: %v", err))
		return 1
	}

	logger := log.NewLogger(cfg.Log)

	var transform store.Transform

	switch cfg.Store {
	case config.DataStoreInfluxDB:
		transform = influxdb.NewTransformer(logger, flagSet.Arg(0))
	}

	startTime := time.Now().UTC()

	if err := transform.Run(); err != nil {
		logger.Error("failed to run transform process", "error", err)
		return 1
	}

	logger.Info("successfully finished transform process", "elapsed_time", time.Since(startTime))
	return 0
}
