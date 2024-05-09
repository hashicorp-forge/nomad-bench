// Copyright (c) HashiCorp, Inc.
// SPDX-License-Identifier: MPL-2.0

package config

type Log struct {
	Level string
	JSON  bool
}

func DefaultLog() *Log {
	return &Log{
		Level: "debug",
		JSON:  false,
	}
}
