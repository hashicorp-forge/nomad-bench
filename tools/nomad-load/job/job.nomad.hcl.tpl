job "dispatch" {
  type = "{{ .JobType }}"

  {{ if .Spread }}
  spread {
    attribute = "${node.datacenter}"
    weight    = 100
  }
  {{ end }}

  {{ range $i, $a := .Groups }}
  group "dispatch{{$i}}" {
    count = {{ .Count }}
    task "dispatch" {
      driver = "mock"
    }
  }
  {{ end }}
}
