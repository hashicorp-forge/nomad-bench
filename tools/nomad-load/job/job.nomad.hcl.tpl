job "dispatch" {
  type = "batch"

  count = {{ .Count }}

  {{ if .Spread }}
  spread {
    attribute = "${node.datacenter}"
    weight    = 100
  }
  {{ end }}

  parameterized {}

  {{ range $i, $a := .Groups }}
  group "dispatch{{$i}}" {
    task "dispatch" {
      driver = "mock"
    }
  }
  {{ end }}
}
