# nomad-bench
This repository contains the code used to provision the infrastructure used to run tests and
benchmarks against Nomad test clusters.

Nomad test clusters are a set of servers with hundreds or thousands of simulated nodes, which are
created using [`nomad-nodesim`][]. The Nomad server processes are not simulated and are expected to
run on their own hosts, mimicking real world deployments. The Nomad servers are the focus of
benchmarking and load testing.

## Repository Structure
The `nomad-bench` repository contains a number of components that work together to create the
benchmarking and load testing environment.

### Infra
The [infra](./infra) directory contains code which manages and handles deployed cloud environments,
and is partitioned by AWS region.

### Shared
The [shared](./shared) directory contains reusable Terraform modules, Ansible roles and collections,
and Nomad job specifications.

### Tools
The [tools](./tools) directory hosts our custom written Go tools which are aimed at running and
recording benchmarking experiments. Please see the [nomad-load readme](./tools/nomad-load/README.md)
and [nomad-metrics readme](./tools/nomad-metrics/README.md) files for more information on each tool
and how to run it.

## Getting Started
To run this project you needs the following tools installed in your machine:
* [Terraform][terraform_install]
* [Python][python_install]
* [Ansible][ansible_install]
* `make`

The project also needs an AWS account where the infrastructure will be built and run. The resources
used have a non-trivial monetary cost associated.

### (Optional) Create a Python Virtual Environment
Virtual environments allow you to isolate Python package installation for
specific projects.

Create and activate a virtual environment in the `./shared/ansible` directory.

```console
cd ./shared/ansible
python -m venv .venv
source .venv/bin/activate
cd ../../
```

### Install Dependencies
Run the `make deps` target from the root to install the dependencies.

```console
make deps
```

### Provision Core Infrastructure
Navigate to the `./infra/eu-west-2/core` directory and edit the empty variables within the
[`terraform.tfvars`](./infra/eu-west-2/core/terraform.tfvars) file to match you requirements and
environment setup.

Once customizations have been made, Terraform can be used to build the infrastructure resources.
```console
terraform init
terraform plan
terraform apply --auto-approve
```

Once the infrastructure has been provisioned, you can extract the mTLS and SSH materials from the
Terraform state. Following the command will detail which files are written to your local machine.
```console
make
```

With the infrastructure is provisioned, run Ansible to configure the base components. This includes
Nomad.
```console
cd ./ansible && ansible-playbook ./playbook.yaml && cd ..
```

Since the cluster was just created, the Nomad ACL system must be bootstrapped. The result Nomad ACL
token is written to `./ansible/nomad-token`.
```console
cd ./ansible && ansible-playbook --tags bootstrap_acl ./playbook_server.yaml && cd ..
```

### Configure Nomad
The base infrastructure has been provisioned, now we need to configure some Nomad resources. From
the `./infra/eu-west-2/core` directory, print the Terraform output and export the `NOMAD_*`
environment variables. 
```console
terraform output message
```

We will also need to export the `NOMAD_TOKEN` environment variable using the bootstrap token which
can be found within `./ansible/nomad-token`.
```console
export NOMAD_TOKEN=e2d9d6e1-8158-0a74-7b09-ecdc23317c51
```

Navigate to the `core-nomad` directory and run Terraform.
```
terraform init
terraform plan
terraform apply --auto-approve
```

Once completed the base nomad-bench infrastructure will be provisioned and running. This includes
InfluxDB which is exposed via the address which can be seen in the Terraform output. The password
for the `admin` user can be found via the Nomad UI variable section under the `nomad/jobs/influxdb`
path.

### Create Test Clusters
The infra directory contains a [template](./infra/eu-west-2/test-cluster-template) that can be
used to create the infrastructure for test cluster. This can simply be copied to generate the base
configuration for a test cluster.
```console
cp -r ./infra/eu-west-2/test-cluster-template ./infra/eu-west-2/test-cluster-<YOUR NAME>
```

The newly created Terraform code requires a single variable to be set via a `tfvars` file. This can
be created using the commands below from inside the new directory.
```console
cd ./infra/eu-west-2/test-cluster-<YOUR NAME>
cat <<EOF > terraform.tfvars
project_name = "test-cluster-<YOUR NAME>"
EOF
```

The test cluster definitions are stored within the `main.tf` file and should be customized before
Terraform is used for provisioning. The `locals` definition, is the most likely area where changes
will be made and serves as a place to add Ansible playbook variables. The below is an example of a
single test cluster, which is setting custom Ansible variables to modify the InfluxDB collection
interval and the Nomad agent in-memory telemetry interval and retention periods.
```terraform
locals {
  test_clusters = {
    (var.project_name) = {
      server_instance_type = "m5.large"
      server_count         = 3
      ansible_server_group_vars = {
        influxdb_telegraf_input_nomad_interval        = "1s"
        nomad_telemetry_in_memory_collection_interval = "1s"
        nomad_telemetry_in_memory_retention_period    = "1m"
      }
    }
  }
}
```

Once customizations have been made, Terraform can be used to build the infrastructure resources.
```console
terraform init
terraform plan
terraform apply --auto-approve
```

With the base infrastructure built, we can configure the EC2 instances using Ansible. Customizations
to Ansible variables can also be made at this point, using the files within `./ansible/group_vars`
and `./ansible/host_vars`.
```console
cd ./ansible && \
  ansible-playbook ./playbook.yaml && \
  cd ..
```

The Ansible playbooks also support compiling, distributing, and running Nomad based on a local copy
of the codebase. This must be run independently of the previous Ansible command, due to the tags
used. It will copy your code to the bastion host and perform a remote compilation, before
downloading the binary, distributing it to EC2 instances, and restarting the Nomad process.
```console
cd ./ansible && \
  ansible-playbook --tags custom_build --extra-vars build_nomad_local_code_path=<PATH_TO_CODE> playbook.yaml
```

#### Test Cluster Nomad Jobs
Terraform produces a number of Nomad job specification files which are designed to be run on the
core cluster, but interact with the test cluster. These are located within the `jobs` directory of
your test cluster infrastructure directory. When performing the job registration, you should ensure
the `NOMAD_*` environment variables are set and point to the core cluster.

The `nomad-nodesim-<CLUSTER NAME>.nomad.hcl` job utilises [`nomad-nodesim`][] to register Nomad
clients with the test cluster servers. By default, it will register 100 clients that are spread
across two datacenters (`dc1`, `dc2`).
```console
nomad job run \
  -var 'group_num=1' \
  ./jobs/nomad-nodesim-<CLUSTER NAME>.nomad.hcl
```

The `nomad-load-<CLUSTER NAME>.nomad.hcl` job utilises the [nomad-load](./tools/nomad-load) in order
to execute load against the Nomad cluster. The job specification should be modified in order to run
the load testing scenario you want. It also includes a [Telegraf][telegraf] task that ships
telemetry data from the load testing tool, to the central [InfluxDB][influxdb] server.
```console
nomad job run \
  ./jobs/nomad-load-<CLUSTER NAME>.nomad.hcl
```

The `nomad-gc-<CLUSTER NAME>.nomad.hcl` job can optionally be run to periodically trigger and run
the Nomad garbage collection process. This helps manage Nomad server memory utilisation in
situations where large number of jobs are being dispatched.
```console
nomad job run \
  -var 'gc_interval_seconds=60' \
  ./jobs/nomad-gc-<CLUSTER NAME>.nomad.hcl
```

## Destroying
Once you have finished with the infrastructure, you should run `terraform destroy` in each
directory where `terraform apply` was previously run.

[`nomad-nodesim`]: https://github.com/hashicorp-forge/nomad-nodesim
[ansible_install]: https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html#selecting-an-ansible-package-and-version-to-install
[terraform_install]: https://developer.hashicorp.com/terraform/install
[python_install]: https://www.python.org/downloads/
[telegraf]: https://www.influxdata.com/time-series-platform/telegraf/
[influxdb]: https://www.influxdata.com/
