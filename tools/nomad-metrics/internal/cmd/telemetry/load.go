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

type LoadCommand struct {
	UI *cli.BasicUi
}

func (l *LoadCommand) Help() string {
	helpText := `
Usage: nomad-metrics telemetry load [options] <path>

  Load reads the data specified as a path argument to this command and loads
  it into the specified data store. The path must contain already transformed
  data which is suitable for the data store.

Load Options:

  -store=<name>
    The name of the data store to load data into. This currently supports
    "influxdb" which is the default.

InfluxDB Options:

  -influxdb-auth-token=<token>
    An InfluxDB API authentication token used for API connectivity. This must
    have write access to the bucket and organization specified below.

  -influxdb-bucket=<bucket>
    The InfluxDB bucket to load the data into. For more information on these,
    see https://docs.influxdata.com/influxdb/v2/admin/buckets/.

  -influxdb-organization=<organization>
    The InfluxDB organization to load the data into and where the bucket also
    exists. For more information on these, see
    https://docs.influxdata.com/influxdb/v2/admin/organizations/.

  -influxdb-server-url=<url>
    The InfluxDB server base URL such as "http://localhost:8086".

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

func (l *LoadCommand) Synopsis() string { return "Load local telemetry data into a datastore" }

func (l *LoadCommand) Name() string { return LoadCommandName }

func (l *LoadCommand) Run(args []string) int {

	flagSet := flag.NewFlagSet(l.Name(), flag.ContinueOnError)
	flagSet.Usage = func() { l.UI.Output(l.Help()) }

	cfg := config.LoadDefault()

	flagSet.StringVar(&cfg.Store, "store", config.DataStoreInfluxDB, "The data store to load data into.")
	flagSet.StringVar(&cfg.InfluxDB.AuthToken, "influxdb-auth-token", "", "")
	flagSet.StringVar(&cfg.InfluxDB.Bucket, "influxdb-bucket", "", "")
	flagSet.StringVar(&cfg.InfluxDB.Organization, "influxdb-organization", "", "")
	flagSet.StringVar(&cfg.InfluxDB.ServerURL, "influxdb-server-url", "", "")

	flagSet.StringVar(&cfg.Log.Level, "log-level", "debug", "")
	flagSet.BoolVar(&cfg.Log.JSON, "log-json", false, "")

	if err := flagSet.Parse(args); err != nil {
		return 1
	}

	if len(flagSet.Args()) != 1 {
		l.UI.Error(fmt.Sprintf("expected one argument, got %v", len(flagSet.Args())))
		return 1
	}

	if err := cfg.Validate(); err != nil {
		l.UI.Error(fmt.Sprintf("failed to validate config: %v", err))
		return 1
	}

	logger := log.NewLogger(cfg.Log)

	var load store.Load

	switch cfg.Store {
	case config.DataStoreInfluxDB:
		load = influxdb.NewLoader(logger, cfg, flagSet.Arg(0))
	}

	startTime := time.Now().UTC()

	if err := load.Run(); err != nil {
		logger.Error("failed to run load process", "error", err)
		return 1
	}

	logger.Info("successfully finished load process", "elapsed_time", time.Since(startTime))
	return 0
}
