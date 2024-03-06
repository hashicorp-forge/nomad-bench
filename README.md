# nomad-bench

This repository contains the code used to provision the infrastructure used to
run tests and benchmarks against Nomad test clusters.

Nomad test clusters are a set of servers with hundreds or thousands of
simulated nodes, which are created using [`nomad-nodesim`][].

## Getting Started

To run this project you needs the following tools installed in your machined:

* [Terraform][terraform_install]
* [Python][python_install]
* [Ansible][ansible_install]
* `make`

### (Optional) Create a Python virtual environment

Virtual environments allow you to isolate Python package installation for
specific projects.

Create and activate a virtual environment in the `./shared/ansible` directory.

```console
cd ./shared/ansible
python -m venv .venv
source .venv/bin/activate
cd ../../
```

### Install dependencies

Run the `make deps` target from the root to install the dependencies.

```console
make deps
```

### Provision core infrastructure

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
ansible-playbook ./ansible/playbook.yaml
```

Since the cluster was just  created, the Nomad ACL system must be bootstrapped.

```console
ansible-playbook --tags=acl_bootstrap ./ansible/playbook_server.yaml
```

The Nomad bootstrap token is written to `./ansible/nomad-token`.

### Run InfluxDB Nomad job

Print the Terraform output, export the `NOMAD_*` environment variables and run
the `influxdb.nomad.hcl` job.

```console
terraform output
```

[`nomad-nodesim`]: https://github.com/hashicorp-forge/nomad-nodesim
[ansible_install]: https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html#selecting-an-ansible-package-and-version-to-install
[terraform_install]: https://developer.hashicorp.com/terraform/install
[python_install]: https://www.python.org/downloads/
