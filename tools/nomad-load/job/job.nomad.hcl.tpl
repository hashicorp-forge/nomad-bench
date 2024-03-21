job "dispatch" {
  type = "batch"

  {{ if .Spread }}
  spread {
    attribute = "${node.datacenter}"
    weight    = 100
  }
  {{ end }}

  parameterized {}

  group "dispatch" {
    task "dispatch" {
      driver = "mock"
    }
  }
}
