package job

import (
	"bytes"
	_ "embed"
	"text/template"
)

//go:embed job.nomad.hcl.tpl
var jobTpl string

type Conf struct {
	Spread bool
}

func Render(cfg Conf) (string, error) {
	t := template.Must(template.New("jobTpl").Parse(jobTpl))

	buf := new(bytes.Buffer)
	err := t.Execute(buf, cfg)
	if err != nil {
		return "", err
	}

	return buf.String(), nil
}
