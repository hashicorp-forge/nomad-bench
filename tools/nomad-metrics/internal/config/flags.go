// Copyright (c) HashiCorp, Inc.
// SPDX-License-Identifier: MPL-2.0

package config

import "time"

type arrayFlagVar []string

func (i *arrayFlagVar) String() string { return "" }

func (i *arrayFlagVar) Set(value string) error {
	*i = append(*i, value)
	return nil
}

type FuncDurationVar func(d time.Duration) error

func (f FuncDurationVar) Set(s string) error {
	v, err := time.ParseDuration(s)
	if err != nil {
		return err
	}
	return f(v)
}

func (f FuncDurationVar) String() string   { return "" }
func (f FuncDurationVar) IsBoolFlag() bool { return false }
