# Nomad Load

`nomad-load` is a simple utility that can be used to generate load on a Nomad cluster.

### Building
The application can quickly be built on any machine with Go installed and the
code checked out.
```shell
$ make
```

### Running
The `nomad-load` binary has help output available which details all the commands
and flags available.
```
./nomad-load -h
```

### Load generation examples

`nomad-load` has many options to generate batch or service job related load
scenarios. Here's an example of running 100 concurrent workers that submit
service type jobs, using the docker driver and continuously updating these jobs
every 50ms:
```
./nomad-load -type=service -workers=100 -updates-delay=50ms -driver=docker
```

Here's another example, of a batch job based load. We're using 10 workers to
produce 100 batch job dispatches with a randomized delay between these
dispatches. Additionally, we set a fixed seed for the RNG, and we spread our
jobs across datacenters:
```
./nomad-load -type=batch -workers=10 -random -num-of-dispatches=100 -seed1=42 -seed2=43 -spread
```

Finally, the example below will spin up service type jobs and produce 1000
updates, starting with delay of 3s and then decreasing the delay in equal amount
of time until it reaches 100ms delay on the last update:
```
./nomad-load -type=service -workers=100 -num-of-updates=1000 -updates-delay=3s -updates-delay-targe=100ms
```