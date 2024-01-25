package main

import (
	"bufio"
	"fmt"
	"os"

	"github.com/hashicorp/team-nomad/tools/nomad-metrics/internal/cmd"
	"github.com/mitchellh/cli"
)

func main() {
	os.Exit(realMain(os.Args[1:]))
}

func realMain(args []string) int {

	ui := &cli.BasicUi{
		Reader:      bufio.NewReader(os.Stdin),
		Writer:      os.Stdout,
		ErrorWriter: os.Stderr,
	}

	cliImpl := &cli.CLI{
		Name:       "nomad-metrics",
		Args:       args,
		Commands:   cmd.Commands(ui),
		HelpFunc:   cli.BasicHelpFunc("nomad-metrics"),
		HelpWriter: os.Stderr,
	}

	exitCode, err := cliImpl.Run()
	if err != nil {
		_, _ = fmt.Fprintf(os.Stderr, "error executing CLI: %v\n", err.Error())
	}
	return exitCode
}
