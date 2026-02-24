# nomad-raft-load

A utility for load testing Nomad's Raft consensus layer by performing operations on Nomad Namespaces, Variables, ACL tokens, and ACL policies.

## Overview

`nomad-raft-load` tests Raft performance by creating and deleting Nomad resources (Namespaces, Variables, ACL tokens, and ACL policies), which are pure Raft operations that don't require client nodes. This allows you to isolate and measure the performance characteristics of Nomad's consensus layer.

## Features

- **Multiple Operation Types**: Test with Nomad Namespaces, Variables, ACL tokens, or ACL policies
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

Test with Nomad Namespaces (default, pure Raft with no encryption overhead):

```bash
./nomad-raft-load \
  -nomad-addr=https://nomad.example.com \
  -type=namespace \
  -pattern=create-delete \
  -rate=10 \
  -workers=5
```

Test with Nomad Variables (works without ACLs, but includes encryption overhead):

```bash
./nomad-raft-load \
  -nomad-addr=https://nomad.example.com \
  -type=variable \
  -pattern=create-delete \
  -rate=10 \
  -workers=5
```

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
- `-type`: Operation type - `namespace`, `variable`, `token`, or `policy` (default: `namespace`)
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
- `nomad_raft_load.variable.created`: Variables created counter
- `nomad_raft_load.variable.deleted`: Variables deleted counter
- `nomad_raft_load.namespace.created`: Namespaces created counter
- `nomad_raft_load.namespace.deleted`: Namespaces deleted counter

## Prerequisites

- Nomad cluster (ACLs optional for variable operations)
- For token/policy operations: ACL system bootstrapped and `NOMAD_TOKEN` environment variable set with a management token
- Go 1.23 or later (for building from source)

## How It Works

### Namespace Operations (Recommended)

When running with `-type=namespace` (the default), the utility creates and deletes Nomad Namespaces with names like `raft-load-ns-{worker}-{iteration}-{timestamp}`.

**Advantages:**
- ✅ Works with or without ACLs enabled
- ✅ Pure Raft operations with no encryption overhead
- ✅ Fastest and cleanest Raft testing
- ✅ No special setup required
- ✅ Tests Raft in isolation

### Variable Operations

When running with `-type=variable`, the utility creates and deletes Nomad Variables at paths like `raft-load/test-{worker}-{iteration}-{timestamp}`. Each variable contains a few test key-value pairs.

**Note:** Variables use encryption, so they test Raft plus encryption overhead. Use namespaces for pure Raft testing.

### Token Operations

When running with `-type=token`, the utility automatically:
1. Creates a base ACL policy (`raft-load-base-policy`) on startup with minimal read permissions
2. Attaches this policy to all created tokens (required by Nomad for client tokens)
3. Cleans up the base policy when the test completes

### Policy Operations

When running with `-type=policy`, the utility directly creates and deletes ACL policies with simple read permissions for the default namespace.

**Note:** Both token and policy operations require ACLs to be enabled on the Nomad cluster.

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

High-rate test with many workers using namespaces:

```bash
./nomad-raft-load \
  -nomad-addr=$NOMAD_ADDR \
  -type=namespace \
  -pattern=create-delete \
  -rate=1000 \
  -burst=100 \
  -workers=50 \
  -duration=10m
```

### Endurance Test

Moderate sustained load with namespaces:

```bash
./nomad-raft-load \
  -nomad-addr=$NOMAD_ADDR \
  -type=namespace \
  -pattern=create-delete \
  -rate=50 \
  -workers=10 \
  -duration=1h
```

### Burst Test

Test burst handling with accumulate-purge using namespaces:

```bash
./nomad-raft-load \
  -nomad-addr=$NOMAD_ADDR \
  -type=namespace \
  -pattern=accumulate-purge \
  -rate=500 \
  -burst=100 \
  -workers=20 \
  -count=10000 \
  -purge-interval=30s
```

### Variable Operations Test

Test with variables (includes encryption overhead):

```bash
./nomad-raft-load \
  -nomad-addr=$NOMAD_ADDR \
  -type=variable \
  -pattern=create-delete \
  -rate=100 \
  -workers=10 \
  -duration=5m
```

### ACL-Specific Test

Test ACL token operations (requires ACL-enabled cluster):

```bash
./nomad-raft-load \
  -nomad-addr=$NOMAD_ADDR \
  -type=token \
  -pattern=create-delete \
  -rate=100 \
  -workers=10 \
  -duration=5m
```
