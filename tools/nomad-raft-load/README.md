# nomad-raft-load

A utility for load testing Nomad's Raft consensus layer by performing ACL operations.

## Overview

`nomad-raft-load` tests Raft performance by creating and deleting ACL tokens and policies, which are pure Raft operations that don't require client nodes. This allows you to isolate and measure the performance characteristics of Nomad's consensus layer.

## Features

- **Multiple Operation Types**: Test with ACL tokens or ACL policies
- **Flexible Patterns**: 
  - `create-only`: Continuously create resources
  - `create-delete`: Create and immediately delete (tests both write paths)
  - `accumulate-purge`: Create many resources, then purge them in bulk
- **Rate Control**: Configurable rate limiting with burst support
- **Randomization**: Optional randomized operation timing
- **Metrics**: Built-in Prometheus metrics via HTTP endpoint
- **Concurrent Workers**: Configurable number of parallel workers

## Installation

```bash
make build
```

Or install directly:

```bash
go install github.com/hashicorp/nomad-bench/tools/nomad-raft-load/cmd/nomad-raft-load@latest
```

## Usage

### Basic Examples

Test with ACL tokens using create-delete pattern:

```bash
./nomad-raft-load \
  -nomad-addr=https://nomad.example.com \
  -type=token \
  -pattern=create-delete \
  -rate=10 \
  -workers=5
```

Test with ACL policies, accumulating and purging periodically:

```bash
./nomad-raft-load \
  -nomad-addr=https://nomad.example.com \
  -type=policy \
  -pattern=accumulate-purge \
  -rate=50 \
  -workers=10 \
  -purge-interval=1m
```

Run for a specific duration:

```bash
./nomad-raft-load \
  -nomad-addr=https://nomad.example.com \
  -type=token \
  -pattern=create-delete \
  -rate=100 \
  -duration=5m
```

### Command-Line Flags

- `-nomad-addr`: Nomad server address (required)
- `-type`: Operation type - `token` or `policy` (default: `token`)
- `-pattern`: Operation pattern - `create-only`, `create-delete`, or `accumulate-purge` (default: `create-delete`)
- `-rate`: Operations per second (default: `10`)
- `-burst`: Burst rate for operations (default: `1`)
- `-workers`: Number of concurrent workers (default: `10 * NumCPU`)
- `-count`: Number of operations per worker (0 = unlimited, default: `0`)
- `-duration`: How long to run the test (0 = until count reached, default: `0`)
- `-purge-interval`: For `accumulate-purge`, how often to purge (0 = only at end, default: `0`)
- `-random`: Randomize operation timing (default: `false`)
- `-seed1`, `-seed2`: Random number generator seeds
- `-http-addr`: HTTP server bind address (default: `0.0.0.0`)
- `-http-port`: HTTP server port (default: `8080`)
- `-log-level`: Log level (default: `INFO`)

## Metrics

Metrics are exposed at `http://localhost:8080/v1/metrics` in Prometheus format.

Key metrics:
- `nomad_raft_load.operation.success`: Successful operations counter
- `nomad_raft_load.operation.errors`: Failed operations counter
- `nomad_raft_load.operation.duration_ms`: Operation duration samples
- `nomad_raft_load.token.created`: Tokens created counter
- `nomad_raft_load.token.deleted`: Tokens deleted counter
- `nomad_raft_load.policy.created`: Policies created counter
- `nomad_raft_load.policy.deleted`: Policies deleted counter

## Prerequisites

- Nomad cluster with ACL system bootstrapped
- `NOMAD_TOKEN` environment variable set with a management token (must have permissions to create/delete ACL tokens and policies)
- Go 1.23 or later (for building from source)

## How It Works

### Token Operations

When running with `-type=token`, the utility automatically:
1. Creates a base ACL policy (`raft-load-base-policy`) on startup with minimal read permissions
2. Attaches this policy to all created tokens (required by Nomad for client tokens)
3. Cleans up the base policy when the test completes

### Policy Operations

When running with `-type=policy`, the utility directly creates and deletes ACL policies with simple read permissions for the default namespace.

## Operation Patterns

### create-only
Creates resources continuously without deleting them. Useful for testing sustained write throughput and observing Raft log growth.

⚠️ **Warning**: This will accumulate resources. Clean up manually or use with finite `-count`.

### create-delete
Creates a resource and immediately deletes it. Tests both write paths and measures round-trip Raft performance.

✅ **Recommended** for most testing scenarios as it's self-cleaning.

### accumulate-purge
Creates resources until a threshold, then deletes them in bulk. Useful for testing:
- Burst creation performance
- Bulk deletion performance  
- Raft log compaction behavior

Use `-purge-interval` for periodic purging during the test.

## Examples

### Stress Test

High-rate test with many workers:

```bash
./nomad-raft-load \
  -nomad-addr=$NOMAD_ADDR \
  -type=token \
  -pattern=create-delete \
  -rate=1000 \
  -burst=100 \
  -workers=50 \
  -duration=10m
```

### Endurance Test

Moderate sustained load:

```bash
./nomad-raft-load \
  -nomad-addr=$NOMAD_ADDR \
  -type=policy \
  -pattern=create-delete \
  -rate=50 \
  -workers=10 \
  -duration=1h
```

### Burst Test

Test burst handling with accumulate-purge:

```bash
./nomad-raft-load \
  -nomad-addr=$NOMAD_ADDR \
  -type=token \
  -pattern=accumulate-purge \
  -rate=500 \
  -burst=100 \
  -workers=20 \
  -count=10000 \
  -purge-interval=30s
```

## Running as a Nomad Job

When using the `test-bench-bootstrap` Terraform module, job files are automatically generated for each cluster in the `jobs/` directory.

The generated job will be named `nomad-raft-load-<cluster-name>.nomad.hcl` and includes:
- The nomad-raft-load task with default test scenarios
- A Telegraf sidecar for metrics collection to InfluxDB
- Proper namespace and cluster configuration

To run the job:

```bash
cd infra/<region>/<environment>
nomad job run jobs/nomad-raft-load-<cluster-name>.nomad.hcl
```

The job template is located at:
`shared/terraform/modules/test-bench-bootstrap/nomad-raft-load.nomad.hcl.tpl`

You can customize the generated job file locally - it won't be overwritten by Terraform unless you explicitly replace the resource:

```bash
terraform apply -replace 'module.bootstrap.terraform_data.nomad_jobs_raft_load["<cluster-name>"]'
```
