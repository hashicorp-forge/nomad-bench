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
The [shared](./shared) directory contains reusable Terraform modules, Ansible roles, and Nomad job
specifications.

### Tools
The [tools](./tools) directory hosts our custom written Go tools which are aimed at running and
recording benchmarking experiments. Please see the [nomad-load readme](./tools/nomad-load/README.md)
and [nomad-metrics readme](./tools/nomad-metrics/README.md) files for more information on each tool
and how to run it.

## Getting Started

To run this project you needs the following tools installed in your machined:

* [Terraform][terraform_install]
* [Python][python_install]
* [Ansible][ansible_install]
* `make`

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

Login to Terraform Cloud.

```console
terraform login
```

Run Terraform from the `./infra/eu-west-2/core` directory.

```console
cd ./infra/eu-west-2/core
terraform init
terraform apply
```

Extract mTLS and SSH materials from the Terraform state.

```console
make
```

Once the infrastructure is provisioned, run Ansible to configure it.

```console
cd ./ansible && ansible-playbook ./playbook.yaml && cd ..
```

Since the cluster was just created, the Nomad ACL system must be bootstrapped.

```console
cd ./ansible && ansible-playbook ./playbook.yaml && cd ..
```

The Nomad bootstrap token is written to `./ansible/nomad-token`.

### Configure Nomad

From the `./infra/eu-west-2/core` directory, print the Terraform output and
export the `NOMAD_*` environment variables.

```console
terraform output message
```

Navigate to the `core-nomad` directory and run Terraform.

```
cd ../core-nomad
terraform init
terraform apply
```

### Create Test Clusters

Copy the directory `./infra/eu-west-2/test-cluster-template` and give it your
own name.

```console
cp -r ./infra/eu-west-2/test-cluster-template ./infra/eu-west-2/test-cluster-<YOUR NAME>
```

Navigate to the new directory and create a `terraform.tfvars` file.

```console
cd ./infra/eu-west-2/test-cluster-<YOUR NAME>
cat <<EOF > terraform.tfvars
project_name = "test-cluster-<YOUR NAME>"
EOF
```

Customize the test cluster definitions in `main.tf` and provision the
infrastructure.

```console
terraform init
terraform apply
```

Run the Ansible playbook to configure the VMs.

```console
cd ./ansible && ansible-playbook ./playbook.yaml && cd ..
```

Customize the generated `nomad-nodesim` jobs and run them. Make sure you still
have the core cluster `NOMAD_*` environment variables defined.

```console
nomad run ./jobs/nomad-nodesim-<CLUSTER NAME>.nomad.hcl
```

[`nomad-nodesim`]: https://github.com/hashicorp-forge/nomad-nodesim
[ansible_install]: https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html#selecting-an-ansible-package-and-version-to-install
[terraform_install]: https://developer.hashicorp.com/terraform/install
[python_install]: https://www.python.org/downloads/
