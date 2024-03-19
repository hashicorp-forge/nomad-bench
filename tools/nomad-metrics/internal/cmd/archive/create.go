package archive

import (
	"flag"
	"fmt"
	"strings"

	"github.com/hashicorp/nomad-bench/nomad-metrics/internal/archive"
	"github.com/hashicorp/nomad-bench/nomad-metrics/internal/config"
	"github.com/hashicorp/nomad-bench/nomad-metrics/internal/log"
	"github.com/mitchellh/cli"
)

type CreateCommand struct {
	UI *cli.BasicUi
}

func (c *CreateCommand) Help() string {
	helpText := `
Usage: nomad-metrics archive <subcommand> [options] [args]

  This command groups subcommands for generating and retrieving archives of test
  data from long term storage.

Create Options:
  -local-telemetry-path=<path>
    The path to locally collected telemetry data as the result of running the
    "telemetry collect" command. Can be left empty if you do not have any data,
    or do not wish to back it up.

  -store=<name>
    The name of the data store to backup. This currently supports "influxdb",
    but defaults to empty, meaning remote data is not backed up.

AWS Options:

  -aws-region=<region>
    The AWS region where the S3 bucket to archive resides. Defaults to
    "us-east-1".

  -aws-s3-bucket=<bucket>
    The AWS S3 bucket name to which the archive will be uploaded to. This must
    exist within the specified AWS region.

  -aws-s3-bucket-key=<key>
    An object key that will serve as a destination directory within the specified
    S3 bucket. This does not need to exist prior to running the command and will
    be created if required.

InfluxDB Options:

  -influxdb-auth-token=<token>
    An InfluxDB API authentication token used for API connectivity.

  -influxdb-bucket=<bucket>
    The InfluxDB bucket to load the data into. For more information on these,
    see https://docs.influxdata.com/influxdb/v2/admin/buckets/.

  -influxdb-organization=<organization>
    The InfluxDB organization to load the data into and where the bucket also
    exists. For more information on these, see
    https://docs.influxdata.com/influxdb/v2/admin/organizations/.

  -influxdb-server-url=<url>
    The InfluxDB server base URL such as "http://localhost:8086".
`
	return strings.TrimSpace(helpText)
}

func (c *CreateCommand) Synopsis() string { return "Create an archive of test data" }

func (c *CreateCommand) Name() string { return CreateCommandName }

func (c *CreateCommand) Run(args []string) int {

	flagSet := flag.NewFlagSet(c.Name(), flag.ContinueOnError)
	flagSet.Usage = func() { c.UI.Output(c.Help()) }

	cfg := config.Archive{
		AWS:      &config.AWS{},
		S3:       &config.AWSS3{},
		InfluxDB: &config.InfluxDB{},
		Log:      &config.Log{},
	}

	flagSet.StringVar(&cfg.Store, "store", "", "")
	flagSet.StringVar(&cfg.LocalTelemetryPath, "local-telemetry-path", "", "")
	flagSet.StringVar(&cfg.AWS.Region, "aws-region", "", "")
	flagSet.StringVar(&cfg.S3.Bucket, "aws-s3-bucket", "", "")
	flagSet.StringVar(&cfg.S3.Key, "aws-s3-bucket-key", "", "")
	flagSet.StringVar(&cfg.InfluxDB.AuthToken, "influxdb-auth-token", "", "")
	flagSet.StringVar(&cfg.InfluxDB.Bucket, "influxdb-bucket", "", "")
	flagSet.StringVar(&cfg.InfluxDB.Organization, "influxdb-organization", "", "")
	flagSet.StringVar(&cfg.InfluxDB.ServerURL, "influxdb-server-url", "", "")
	flagSet.StringVar(&cfg.Log.Level, "log-level", "debug", "")
	flagSet.BoolVar(&cfg.Log.JSON, "log-json", false, "")

	if err := flagSet.Parse(args); err != nil {
		return 1
	}

	if len(flagSet.Args()) > 0 {
		c.UI.Error("this command does not accept any arguments")
		return 1
	}

	if err := cfg.Validate(); err != nil {
		c.UI.Error(fmt.Sprintf("failed to validate config: %v", err))
		return 1
	}

	logger := log.NewLogger(cfg.Log)

	arch, err := archive.New(&cfg, logger)
	if err != nil {
		c.UI.Error(fmt.Sprintf("failed to instatiate archiver: %v", err))
		return 1
	}

	if err := arch.Create(); err != nil {
		c.UI.Error(fmt.Sprintf("failed to create archive: %v", err))
		return 1
	}
	return 0
}
