{{ $c := .Count }}
job "dispatch_{{$c}}" {
  type = "{{ .JobType }}"


  {{ if .Spread }}
  spread {
    attribute = "${node.datacenter}"
    weight    = 100
  }
  {{ end }}

  {{ if ne .JobType "service" }}
  parameterized {}
  {{ end }}

  {{ range $i, $a := .Groups }}
  group "dispatch_{{$c}}_{{$i}}" {
    count = {{ $c }}
    task "dispatch_{{$c}}_{{$i}}" {
      driver = "mock"
    }
  }
  {{ end }}
}
