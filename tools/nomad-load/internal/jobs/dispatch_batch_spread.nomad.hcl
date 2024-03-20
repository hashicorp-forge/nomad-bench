job "dispatch" {
  type = "batch"

  spread {
    attribute = "${node.datacenter}"
    weight    = 100
  }

  parameterized {}

  group "dispatch" {
    task "dispatch" {
      driver = "mock"
    }
  }
}
