# Nomad Metrics
Nomad Metrics is a lightweight tool for collecting and storing Nomad agent telemetry data. It is
designed to offer an alternative to the `nomad operator debug` command in situations where only the
telemetry data is required. It does not collect pprof or API data, meaning it does not impact the
Nomad processes performance.

### Building
The application can quickly be built on any machine with Go installed and the
code checked out.
```shell
$ go build .
```

### Running
The `nomad-metrics` binary has help output available which details all the commands and flags
available.
```
./nomad-metrics -h
```

#### `telemtry collect` Example
The `telemetry collect` command scrapes the configuration Nomad agents metric API endpoint and
writes this data locally.
```
./nomad-metrics telemetry collect \
  -nomad-address=https://192.168.1.110:4646 \
  -nomad-address=https://192.168.1.111:4646 \
  -nomad-address=https://192.168.1.112:4646 \
  -nomad-tls-ca-cert=/Users/jrasell/Projects/Infra/dev-mess/nomad/lab/.tls/nomad-agent-ca.pem \
  -nomad-token=60635215-69a1-6e4e-e2a0-a4d187fd7a6b \
  -scrape-name=jrasell-demo \
  -scrape-interval=1s \
  -scrape-duration=30m
```

##### Collect ACL Requirements
When running against a Nomad cluster with ACLs enabled, the provided token will require `agent:read`
capabilities. This allows it to collect metadata from the `/agent/self` endpoint.
```hcl
agent {
  policy = "read"
}
```

##### Collect Results
The results are stored within a directory local prefixed with `nomad-metrics-` followed by a short
UUID. Inside this directory will be a subdirectory for each Nomad agent that has been scraped for
metrics. These directories use the agents name. There will also be a `metadata.json` file which
contains data about the collection run.

##### Collect Metadata
The metadata file contains information which identifies the agents and collection run. This is
useful when comparing different datasets.

* `Agents`: The mapping of the Nomad agent name to the return object of the `/agent/self` endpoint.
* `Path`: The output directory that contains the collected data.
* `Name`: The custom identifier for this collection run.
* `StartTime`: The time at which the metrics collection started.
* `EndTime`: The time at which the metrics collection ended.
* `Name`: The unique name provide to the collection run by the operator.

#### `telemtry transform` Example
The `telemetry transform` command parses and transforms previously scraped JSON telemetry data into
the format required by the specified store. The transformed data will be written to a subdirectory
inside the passed path. In the below example this will be `nomad-metrics-0e7f3f26/influxdb`. The
original data is left untouched.
```
./nomad-metrics telemetry transform \
  -store=influxdb \
  nomad-metrics-0e7f3f26
```

#### `telemtry load` Example
The `telemetry load` command loads telemetry data into the specified data store.
```
./nomad-metrics telemetry load \
  -store=influxdb \
  -influxdb-auth-token=yo21OVmE3519Rj1M1ZQqwllUvgedmpYGh4cC6eksXt1uXcHcF47bSypJ9OVkEJhOIA7a8jN0kCU3jwa0rbJjeQ== \
  -influxdb-organization=hashicorp \
  -influxdb-bucket=jrasell \
  -influxdb-server-url=http://192.168.1.120:24341 \
  nomad-metrics-0e7f3f26/influxdb/
```

## Future Potential
* Commands for processing and examining telemetry data
* Additional cluster metadata
