package config

import (
	"errors"
	"fmt"

	"github.com/hashicorp/go-multierror"
)

type Load struct {
	Log      *Log
	Store    string
	InfluxDB *InfluxDB
}

type InfluxDB struct {
	AuthToken    string
	Bucket       string
	Organization string
	ServerURL    string
}

func LoadDefault() *Load {
	return &Load{
		Log:      DefaultLog(),
		Store:    DataStoreInfluxDB,
		InfluxDB: &InfluxDB{},
	}
}

func (l *Load) Validate() error {
	switch l.Store {
	case DataStoreInfluxDB:
		return l.InfluxDB.validate()
	default:
		return fmt.Errorf("unsupported data store: %q", l.Store)
	}
}

func (i *InfluxDB) validate() error {

	var err multierror.Error

	if i.AuthToken == "" {
		err.Errors = append(err.Errors, errors.New("authentication token required"))
	}
	if i.Bucket == "" {
		err.Errors = append(err.Errors, errors.New("bucket required"))
	}
	if i.Organization == "" {
		err.Errors = append(err.Errors, errors.New("organization required"))
	}
	if i.ServerURL == "" {
		err.Errors = append(err.Errors, errors.New("server URL required"))
	}

	return err.ErrorOrNil()
}
