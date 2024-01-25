package config

import (
	"fmt"
)

type Transform struct {
	Log   *Log
	Store string
}

func TransformDefault() *Transform {
	return &Transform{
		Log:   DefaultLog(),
		Store: DataStoreInfluxDB,
	}
}

func (t *Transform) Validate() error {
	switch t.Store {
	case DataStoreInfluxDB:
		return nil
	default:
		return fmt.Errorf("unsupported data store: %q", t.Store)
	}
}
