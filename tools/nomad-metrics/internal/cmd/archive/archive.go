package archive

import (
	"strings"

	"github.com/mitchellh/cli"
)

const (
	CommandName       = "archive"
	CreateCommandName = "archive create"
)

type Command struct {
	UI *cli.BasicUi
}

func (c *Command) Help() string {
	helpText := `
Usage: nomad-metrics archive <subcommand> [options] [args]

  This command groups subcommands for generating archives of test data by placing
  them into long term storage.

  Please see the individual subcommand help for detailed usage information.
`
	return strings.TrimSpace(helpText)
}

func (c *Command) Synopsis() string { return "Archive test data" }

func (c *Command) Name() string { return CommandName }

func (c *Command) Run(_ []string) int { return cli.RunResultHelp }
