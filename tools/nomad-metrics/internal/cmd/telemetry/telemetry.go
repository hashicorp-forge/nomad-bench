package telemetry

import (
	"strings"

	"github.com/mitchellh/cli"
)

const (
	CommandName          = "telemetry"
	CollectCommandName   = "telemetry collect"
	LoadCommandName      = "telemetry load"
	TransformCommandName = "telemetry transform"
)

type Command struct {
	UI *cli.BasicUi
}

func (c *Command) Help() string {
	helpText := `
Usage: nomad-metrics telemetry <subcommand> [options] [args]

  This command groups subcommands for collecting, transforming, and loading
  Nomad agent JSON telemetry data into storage engines.

  Please see the individual subcommand help for detailed usage information.
`
	return strings.TrimSpace(helpText)
}

func (c *Command) Synopsis() string { return "Collect and transform Nomad telemetry data" }

func (c *Command) Name() string { return CommandName }

func (c *Command) Run(_ []string) int { return cli.RunResultHelp }
