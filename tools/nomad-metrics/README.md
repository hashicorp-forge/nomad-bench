# Nomad Metrics
Nomad Metrics is a lightweight tool for collecting and storing Nomad agent telemetry data. It is
designed to offer an alternative to the `nomad operator debug` command in situations where only the
telemetry data is required. It can be run without needing any Nomad agent configuration parameters
being set, and does not collect pprof or API data, meaning it does not impact the Nomad processes
performance.

### Building
The application can quickly be built on any machine with Go installed and the
code checked out.
```shell
$ go build .
```

### Running
The `nomad-metrics` binary can be triggered without any additional configuration when testing
against a local Nomad dev agent.
```
./nomad-metrics
```

This example demonstrates use of commonly used flags.
```
./nomad-metrics \
  -nomad-address=https://192.168.1.110:4646 \
  -nomad-address=https://192.168.1.111:4646 \
  -nomad-address=https://192.168.1.112:4646 \
  -nomad-tls-ca-cert=/Users/jrasell/Projects/Infra/dev-mess/nomad/lab/.tls/nomad-agent-ca.pem \
  -nomad-token=60635215-69a1-6e4e-e2a0-a4d187fd7a6b \
  -scrape-name=jrasell-demo \
  -scrape-interval=1s \
  -scrape-duration=30m
```

#### Flags
The available flags can be seen by using the `-h` flags such as `nomad-metrics -h`.

* `nomad-address`: The Nomad HTTP API endpoints to scrape. This can be supplied multiple times to
  scrape from multiple Nomad agents.
* `nomad-token`: The ACL token to use for secured endpoint calls.
* `nomad-region`: The Nomad region identifier to connect.
* `nomad-tls-client-cert`: Path to a PEM encoded client certificate.
* `nomad-tls-client-key`: Path to an unencrypted PEM encoded private key matching the client
  certificate.
* `nomad-tls-insecure`: Do not verify the TLS certificate.
* `nomad-tls-server-name`: The server name to use as the SNI host.
* `nomad-tls.ca-cert`: Path to a PEM encoded CA cert file.
* `scrape-duration`: The total duration to scrape as a time duration such as `10m`. The default of
  `0` means the process will scrape indefinitely until the user interrupts the process.
* `scrape-interval`: The interval between scrapes as a time duration such as `1s`. Defaults to `5s`.
* `scrape-name`: Custom identifier name for this collection run.

#### ACL Requirements
When running against a Nomad cluster with ACLs enabled, the provided token will require `agent:read`
capabilities. This allows it to collect metadata from the `/agent/self` endpoint.
```hcl
agent {
  policy = "read"
}
```

### Results
The results are stored within a directory local prefixed with `nomad-metrics-` followed by a short
UUID. Inside this directory will be a subdirectory for each Nomad agent that has been scraped for
metrics. These directories use the agents name. There will also be a `metadata.json` file which
contains data about the collection run.

#### Metadata
The metadata file contains information which identifies the agents and collection run. This is
useful when comparing different datasets.

* `Agents`: The mapping of the Nomad agent name to the return object of the `/agent/self` endpoint.
* `Path`: The output directory that contains the collected data.
* `Name`: The custom identifier for this collection run.
* `StartTime`: The time at which the metrics collection started.
* `EndTime`: The time at which the metrics collection ended.
* `Name`: The unique name provide to the collection run by the operator.

## Future Potential
* Commands for processing and examining telemetry data
* Additional cluster metadata
