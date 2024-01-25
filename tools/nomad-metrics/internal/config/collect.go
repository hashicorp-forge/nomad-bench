package config

import "time"

type Collect struct {
	Log    *Log
	Nomad  *Nomad
	Scrape *Scrape
}

type Scrape struct {
	Name     string
	Interval time.Duration
	Duration time.Duration
}

type Nomad struct {
	Addresses arrayFlagVar
	Region    string
	Token     string
	TLS       *NomadTLS
}

type NomadTLS struct {
	CACert     string
	ClientCert string
	ClientKey  string
	ServerName string
	Insecure   bool
}

func DefaultCollect() *Collect {
	return &Collect{
		Log: DefaultLog(),
		Nomad: &Nomad{
			Addresses: []string{},
			Region:    "",
			Token:     "",
			TLS:       &NomadTLS{},
		},
		Scrape: &Scrape{
			Name:     "",
			Interval: 5 * time.Second,
			Duration: 0 * time.Minute,
		},
	}
}
