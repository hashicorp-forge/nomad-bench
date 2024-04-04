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
