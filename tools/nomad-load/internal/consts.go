// Copyright (c) HashiCorp, Inc.
// SPDX-License-Identifier: MPL-2.0

package internal

type JobType string

const (
	// we currently support batch and service jobs
	JobTypeBatch   = "batch"
	JobTypeService = "service"

	// we currently support docker and mock drivers
	JobDriverDocker = "docker"
	JobDriverMock   = "mock"
)
