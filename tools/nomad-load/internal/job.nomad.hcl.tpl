{{ $w := .Worker }}
{{ $c := .Count }}
{{ $d := .Driver }}
{{ $e := .Echo }}
{{ $t := .JobType }}

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
      driver = "mock_driver"

      config {
        run_for = "10s"
      }
    }
    {{ else if eq $d "docker" }}
    task "echo" {
      driver = "docker"
      {{ if eq $t "service" }}
      config {
        image = "hashicorp/http-echo:1.0.0"
        args  = ["-text", "{{ $e }}"]
      }
      {{ else if eq $t "batch" }}
      config {
        image   = "busybox:1.36.1"
        command = "echo"
        args = ["{{ $e }}"]
      }
      {{ end }}
    }
    {{ end }}
  }
  {{ end }}
}
