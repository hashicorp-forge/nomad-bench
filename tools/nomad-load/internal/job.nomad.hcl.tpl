{{ $w := .Worker }}
{{ $c := .Count }}
{{ $d := .Driver }}
{{ $e := .Echo }}

job "test_job_{{$w}}_{{$c}}" {
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
  group "test_job_group_{{$w}}_{{$c}}_{{$i}}" {
    count = {{ $c }}
    {{ if eq $d "mock" }}
    task "test_job_task_{{$w}}_{{$c}}_{{$i}}" {
      driver = "mock"
    }
    {{ else if eq $d "docker" }}
    task "echo" {
      driver = "docker"

      config {
        image = "hashicorp/http-echo"
        args  = ["-text", "{{ $e }}"]
      }
    }
    {{ end }}
  }
  {{ end }}
}
