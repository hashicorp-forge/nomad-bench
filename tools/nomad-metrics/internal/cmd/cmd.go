package cmd

import (
	"github.com/hashicorp/nomad-bench/nomad-metrics/internal/cmd/telemetry"
	"github.com/mitchellh/cli"
)

func Commands(ui *cli.BasicUi) map[string]cli.CommandFactory {
	return map[string]cli.CommandFactory{
		telemetry.CommandName:          func() (cli.Command, error) { return &telemetry.Command{UI: ui}, nil },
		telemetry.CollectCommandName:   func() (cli.Command, error) { return &telemetry.CollectCommand{UI: ui}, nil },
		telemetry.LoadCommandName:      func() (cli.Command, error) { return &telemetry.LoadCommand{UI: ui}, nil },
		telemetry.TransformCommandName: func() (cli.Command, error) { return &telemetry.TransformCommand{UI: ui}, nil },
	}
}
