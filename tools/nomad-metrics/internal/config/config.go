package config

import "time"

type Config struct {
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

func Default() *Config {
	return &Config{
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
